import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/backend_config.dart';
import '../services/local_evidence_store.dart';
import '../widgets/app_drawer.dart';

class EvidencePage extends StatefulWidget {
  const EvidencePage({super.key});

  @override
  State<EvidencePage> createState() => _EvidencePageState();
}

class _EvidencePageState extends State<EvidencePage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  bool _offlineLocal = false;

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadEvidence() async {
    setState(() {
      _loading = true;
      _error = null;
      _offlineLocal = false;
    });
    try {
      final uri = Uri.parse("${BackendConfig.baseUrl}/evidence");
      final response = await http.get(uri).timeout(const Duration(seconds: 2));
      
      if (response.statusCode != 200) {
        throw Exception("HTTP ${response.statusCode}");
      }
      
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      final rawItems = (jsonData["items"] as List<dynamic>? ?? const []);
      
      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
          
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      // Fallback to local evidence vault (offline-first).
      try {
        final local = await LocalEvidenceStore().list();
        final items = local.map((e) => e.toJson()).toList(growable: false);
        if (!mounted) return;
        setState(() {
          _items = items;
          _offlineLocal = true;
          _error = null;
        });
      } catch (e2) {
        if (!mounted) return;
        setState(() => _error = "${e.toString()}\nLocal vault failed: ${e2.toString()}");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("EVIDENCE"),
        actions: [
          IconButton(onPressed: _loadEvidence, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text("Failed to load evidence.\n$_error",
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
      ));
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _offlineLocal ? "No local evidence captured yet." : "No evidence captured yet.",
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final String? localPath = item["local_path"]?.toString();
        final bool isLocal = localPath != null && localPath.isNotEmpty;

        // Prefer the backend-provided URL; fall back to the legacy pattern.
        final String fileName = (item["file"] ?? "").toString();
        final String rawUrl =
            (item["image_url"] ?? "${BackendConfig.baseUrl}/evidence/$fileName")
                .toString();
        final String timestamp = (item["modified"] ?? "Unknown time").toString();
        final String reason = (item["reason"] ?? "unknown").toString();
        final String location = (item["location"] ?? "Unknown Location").toString();
        final String imageUrl = (() {
          // Add a cache buster so the latest image shows after refresh.
          // (Some devices/CDNs cache by URL; if filenames repeat, you keep seeing the old photo.)
          try {
            final uri = Uri.parse(rawUrl);
            final qp = Map<String, String>.from(uri.queryParameters);
            qp["v"] = timestamp;
            return uri.replace(queryParameters: qp).toString();
          } catch (_) {
            final joiner = rawUrl.contains("?") ? "&" : "?";
            return "$rawUrl${joiner}v=$timestamp";
          }
        })();

        final String heroTag = isLocal ? "local:$localPath" : "remote:$imageUrl";

        void openViewer() {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EvidenceImageViewer(
                heroTag: heroTag,
                isLocal: isLocal,
                localPath: isLocal ? localPath : null,
                imageUrl: isLocal ? null : imageUrl,
              ),
            ),
          );
        }

        void openActions() {
          _showActionsSheet(
            index: index,
            isLocal: isLocal,
            localPath: localPath,
            fileName: fileName,
            imageUrl: imageUrl,
          );
        }

        return Card(
          color: const Color(0xFF1B1B1B),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: openViewer,
            onLongPress: openActions,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Hero(
                      tag: heroTag,
                      child: isLocal
                          ? Image.file(
                              File(localPath),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[800],
                                child: const Icon(Icons.broken_image, color: Colors.white54),
                              ),
                            )
                          : Image.network(
                              imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[800],
                                child: const Icon(Icons.broken_image, color: Colors.white54),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Intruder Detected",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Location: $location",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          "Time: ${_offlineLocal ? "$timestamp (local)" : timestamp}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          "Source: $reason",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List> _loadItemBytes({
    required bool isLocal,
    required String? localPath,
    required String imageUrl,
  }) async {
    if (isLocal) {
      if (localPath == null || localPath.isEmpty) {
        throw Exception("Local path missing");
      }
      return File(localPath).readAsBytes();
    }

    final uri = Uri.parse(imageUrl);
    final resp = await http.get(uri).timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) throw Exception("HTTP ${resp.statusCode}");
    return resp.bodyBytes;
  }

  Future<void> _saveToGallery({
    required bool isLocal,
    required String? localPath,
    required String imageUrl,
    required String fileName,
  }) async {
    try {
      final bytes = await _loadItemBytes(isLocal: isLocal, localPath: localPath, imageUrl: imageUrl);
      final baseName = fileName.isEmpty ? "securax_evidence" : fileName.replaceAll(RegExp(r"\.[^.]+$"), "");
      await Gal.putImageBytes(bytes, album: "Securax", name: baseName);
      _showSnack("Saved to gallery");
    } catch (e) {
      _showSnack("Save failed: ${e.toString()}");
    }
  }

  Future<void> _shareItem({
    required bool isLocal,
    required String? localPath,
    required String imageUrl,
    required String fileName,
  }) async {
    try {
      if (isLocal) {
        if (localPath == null || localPath.isEmpty) throw Exception("Local path missing");
        await Share.shareXFiles([XFile(localPath)], text: "Securax evidence");
        return;
      }

      final bytes = await _loadItemBytes(isLocal: false, localPath: null, imageUrl: imageUrl);
      final dir = await getTemporaryDirectory();
      final safeName = (fileName.isEmpty ? "securax_evidence.jpg" : fileName)
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");
      final tmp = File("${dir.path}/$safeName");
      await tmp.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(tmp.path)], text: "Securax evidence");
    } catch (e) {
      _showSnack("Share failed: ${e.toString()}");
    }
  }

  Future<void> _deleteItem({
    required int index,
    required bool isLocal,
    required String? localPath,
    required String fileName,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete evidence?"),
        content: const Text("This will permanently remove the image."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      if (isLocal) {
        if (localPath == null || localPath.isEmpty) throw Exception("Local path missing");
        final f = File(localPath);
        if (await f.exists()) await f.delete();
      } else {
        if (fileName.isEmpty) throw Exception("Remote filename missing");
        final uri = Uri.parse("${BackendConfig.baseUrl}/evidence/$fileName");
        final resp = await http.delete(uri).timeout(const Duration(seconds: 3));
        if (resp.statusCode != 200 && resp.statusCode != 404) {
          throw Exception("HTTP ${resp.statusCode}");
        }
      }

      if (!mounted) return;
      setState(() {
        final list = List<Map<String, dynamic>>.from(_items);
        list.removeAt(index);
        _items = list;
      });
      _showSnack("Deleted");
    } catch (e) {
      _showSnack("Delete failed: ${e.toString()}");
    }
  }

  void _showActionsSheet({
    required int index,
    required bool isLocal,
    required String? localPath,
    required String fileName,
    required String imageUrl,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text("Save"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _saveToGallery(
                    isLocal: isLocal,
                    localPath: localPath,
                    imageUrl: imageUrl,
                    fileName: fileName,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text("Share"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareItem(
                    isLocal: isLocal,
                    localPath: localPath,
                    imageUrl: imageUrl,
                    fileName: fileName,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteItem(index: index, isLocal: isLocal, localPath: localPath, fileName: fileName);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class EvidenceImageViewer extends StatelessWidget {
  final String heroTag;
  final bool isLocal;
  final String? localPath;
  final String? imageUrl;

  const EvidenceImageViewer({
    super.key,
    required this.heroTag,
    required this.isLocal,
    required this.localPath,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final Widget img = isLocal
        ? Image.file(File(localPath!), fit: BoxFit.contain)
        : Image.network(imageUrl!, fit: BoxFit.contain);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Evidence"),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: img,
          ),
        ),
      ),
    );
  }
}
