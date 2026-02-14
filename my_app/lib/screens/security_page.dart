import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/evidence_service.dart';
import '../widgets/app_drawer.dart';
import 'password_settings_page.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  int failedAttemptsTrigger = 1;
  bool _captureOnWrongPin = false;
  bool _systemMonitoringEnabled = false;
  bool _isAdminActive = false;
  static const _platform = MethodChannel('com.example.securax/admin');

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAdminStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh status when coming back from system settings screens.
    _checkAdminStatus();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      failedAttemptsTrigger = prefs.getInt('failed_attempts_trigger') ?? 1;
      _captureOnWrongPin = prefs.getBool('capture_on_wrong_pin') ?? false;
      _systemMonitoringEnabled = prefs.getBool('system_monitoring_enabled') ?? false;
    });
  }

  Future<void> _checkAdminStatus() async {
    try {
      final bool active = await _platform.invokeMethod('isAdminActive');
      if (!mounted) return;
      setState(() => _isAdminActive = active);
    } catch (_) {
      // Ignore: on non-Android platforms this method channel may not exist.
    }
  }

  Future<void> _saveTrigger(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('failed_attempts_trigger', value);
    if (!mounted) return;
    setState(() => failedAttemptsTrigger = value);
  }

  Future<void> _setSystemMonitoring(bool value) async {
    if (value) {
      // Ensure camera permission is granted before arming system monitoring.
      try {
        await EvidenceService().initCamera();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission is required to arm system monitoring.")),
        );
        return;
      }

      try {
        await _platform.invokeMethod('requestAdmin');
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to open Device Admin permission screen.")),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('system_monitoring_enabled', value);
    if (!mounted) return;
    setState(() => _systemMonitoringEnabled = value);

    // Refresh status (user may have granted/denied on the system screen).
    await _checkAdminStatus();
  }

  Future<void> _setCaptureOnWrongPin(bool value) async {
    if (value) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Enable Evidence Capture?"),
          content: const Text(
            "When enabled, Securax will use the front camera to capture evidence "
            "after failed PIN attempts inside the app. Android will ask for Camera permission.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Enable")),
          ],
        ),
      );
      if (ok != true) return;

      try {
        await EvidenceService().initCamera();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera not available or permission denied.")),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('capture_on_wrong_pin', value);
    if (!value) {
      // Best-effort: release the camera when disabled.
      EvidenceService().dispose();
    }
    if (!mounted) return;
    setState(() => _captureOnWrongPin = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("SECURITY"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader("System Monitoring"),
          Card(
            color: const Color(0xFF1B1B1B),
            child: SwitchListTile(
              title: const Text("Wrong Phone Password", style: TextStyle(color: Colors.white)),
              subtitle: Text(
                _isAdminActive
                    ? "Armed: system lockscreen failures will trigger capture"
                    : "Requires Device Admin permission (tap to enable)",
                style: const TextStyle(color: Colors.white70),
              ),
              value: _systemMonitoringEnabled,
              activeThumbColor: Colors.greenAccent,
              onChanged: _setSystemMonitoring,
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader("Evidence Capture (In App)"),
          Card(
            color: const Color(0xFF1B1B1B),
            child: SwitchListTile(
              title: const Text("Capture On Wrong PIN", style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                "Uses front camera after failed app PIN attempts",
                style: TextStyle(color: Colors.white70),
              ),
              value: _captureOnWrongPin,
              activeThumbColor: Colors.greenAccent,
              onChanged: _setCaptureOnWrongPin,
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader("Sensitivity"),
          Card(
            color: const Color(0xFF1B1B1B),
            child: Column(
              children: [
                const ListTile(
                  title: Text("Trigger Threshold", style: TextStyle(color: Colors.white)),
                  subtitle: Text("Failed attempts before capturing", style: TextStyle(color: Colors.white70)),
                ),
                Slider(
                  value: failedAttemptsTrigger.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: "$failedAttemptsTrigger Attempts",
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => _saveTrigger(v.toInt()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader("App Access"),
          Card(
            color: const Color(0xFF1B1B1B),
            child: ListTile(
              leading: const Icon(Icons.lock, color: Colors.white),
              title: const Text("App Password", style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const PasswordSettingsPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Text(
        title,
        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
      ),
    );
  }
}
