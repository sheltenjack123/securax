import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/backend_config.dart';
import '../services/local_evidence_store.dart';
import '../widgets/app_drawer.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  bool _offlineLocal = false;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
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
      // Fallback to local evidence vault.
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
        title: const Text("ACTIVITY"),
        actions: [IconButton(onPressed: _loadActivity, icon: const Icon(Icons.refresh))],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "Failed to load activity.\n$_error",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text("No real activity yet.", style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final fileName = item["file"]?.toString() ?? "unknown.jpg";
        final modified = item["modified"]?.toString() ?? "unknown";
        final reason = item["reason"]?.toString() ?? "unknown";
        return _LogTile(
          title: "Intrusion Attempt",
          sub: "${_offlineLocal ? '[LOCAL] ' : ''}Captured evidence ($reason): $fileName",
          time: modified,
          isAlert: true,
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  final String title;
  final String sub;
  final String time;
  final bool isAlert;

  const _LogTile({
    required this.title,
    required this.sub,
    required this.time,
    required this.isAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        border: Border(left: BorderSide(color: isAlert ? Colors.red : Colors.green, width: 4)),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(sub, style: const TextStyle(color: Colors.white70)),
        trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ),
    );
  }
}
