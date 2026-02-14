import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

class LocalEvidenceItem {
  final String fileName;
  final String path;
  final String reason;
  final DateTime modified;

  const LocalEvidenceItem({
    required this.fileName,
    required this.path,
    required this.reason,
    required this.modified,
  });

  Map<String, dynamic> toJson() => {
        "file": fileName,
        "local_path": path,
        "reason": reason,
        "modified": modified.toIso8601String(),
      };
}

class LocalEvidenceStore {
  static final LocalEvidenceStore _instance = LocalEvidenceStore._internal();
  factory LocalEvidenceStore() => _instance;
  LocalEvidenceStore._internal();

  // Keep only the latest N evidence images on-device.
  static const int maxItemsToKeep = 10;

  static final RegExp _unsafeReason = RegExp(r"[^a-zA-Z0-9_-]+");

  Future<Directory> _vaultDir() async {
    // Keep in sync with Android native CameraService (uses filesDir/evidence_vault).
    final base = await getApplicationSupportDirectory();
    final dir = Directory("${base.path}/evidence_vault");
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _safeReason(String reason) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return "unknown";
    final safe = trimmed.replaceAll(_unsafeReason, "_").replaceAll(RegExp(r"_+"), "_");
    return safe.replaceAll(RegExp(r"^_+|_+$"), "").isEmpty ? "unknown" : safe;
  }

  String _randSuffix(int len) {
    const chars = "0123456789abcdef";
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _fileName({required String reason, required String ext}) {
    final now = DateTime.now();
    final ts =
        "${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}"
        "_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}"
        "_${now.millisecond.toString().padLeft(3, '0')}";
    final safe = _safeReason(reason);
    return "${ts}_${safe}_${_randSuffix(6)}.$ext";
  }

  Future<LocalEvidenceItem> saveFromFile(
    File source, {
    required String reason,
  }) async {
    final dir = await _vaultDir();

    final ext = (() {
      final name = source.path.split(Platform.pathSeparator).last;
      final dot = name.lastIndexOf(".");
      if (dot <= 0 || dot == name.length - 1) return "jpg";
      final e = name.substring(dot + 1).toLowerCase();
      return e.isEmpty ? "jpg" : e;
    })();

    final fileName = _fileName(reason: reason, ext: ext);
    final dest = File("${dir.path}/$fileName");
    await source.copy(dest.path);

    final stat = await dest.stat();
    // Enforce retention after every capture so the vault can't grow unbounded.
    await prune(keep: maxItemsToKeep);
    return LocalEvidenceItem(
      fileName: fileName,
      path: dest.path,
      reason: _safeReason(reason),
      modified: stat.modified,
    );
  }

  Future<void> prune({int keep = maxItemsToKeep}) async {
    if (keep <= 0) return;
    final dir = await _vaultDir();
    if (!await dir.exists()) return;

    // List newest-first, then delete the rest.
    final items = await list();
    if (items.length <= keep) return;

    for (final item in items.skip(keep)) {
      try {
        final f = File(item.path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
        // Best effort; avoid breaking capture flow due to FS errors.
      }
    }
  }

  Future<List<LocalEvidenceItem>> list() async {
    final dir = await _vaultDir();
    final items = <LocalEvidenceItem>[];

    if (!await dir.exists()) return items;

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      final lower = name.toLowerCase();
      if (!(lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png"))) continue;

      String reason = "unknown";
      final base = name;
      final parts = base.split("_");
      // <yyyymmdd>_<hhmmss>_<ms>_<reason>_<suffix>.jpg
      if (parts.length >= 5) {
        // Reason itself may contain underscores, so join all middle segments.
        final r = parts.sublist(3, parts.length - 1).join("_");
        reason = r.isEmpty ? "unknown" : r;
      }

      final stat = await entity.stat();
      items.add(
        LocalEvidenceItem(
          fileName: name,
          path: entity.path,
          reason: reason,
          modified: stat.modified,
        ),
      );
    }

    items.sort((a, b) => b.modified.compareTo(a.modified));
    return items;
  }
}
