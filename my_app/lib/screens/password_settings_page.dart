import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'change_pin_page.dart';

class PasswordSettingsPage extends StatefulWidget {
  const PasswordSettingsPage({super.key});

  @override
  State<PasswordSettingsPage> createState() => _PasswordSettingsPageState();
}

class _PasswordSettingsPageState extends State<PasswordSettingsPage> {
  bool _isLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isLockEnabled = prefs.getBool('is_lock_enabled') ?? false;
    });
  }

  Future<void> _toggleLock(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_lock_enabled', value);
    if (!mounted) return;
    setState(() => _isLockEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(title: const Text("Password Access"), backgroundColor: Colors.green[800]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            activeThumbColor: Colors.greenAccent,
            title: const Text("Enable App Lock", style: TextStyle(color: Colors.white)),
            subtitle: Text(_isLockEnabled ? "App Locked on Startup" : "App Unlocked (Trap Disabled)", style: const TextStyle(color: Colors.white70)),
            value: _isLockEnabled,
            onChanged: _toggleLock,
          ),
          const Divider(color: Colors.white24),
          if (_isLockEnabled) ...[
            ListTile(
              title: const Text("Change Real PIN", style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePinPage(isRealPin: true))),
            ),
            ListTile(
              title: const Text("Change Trap PIN", style: TextStyle(color: Colors.redAccent)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePinPage(isRealPin: false))),
            ),
          ]
        ],
      ),
    );
  }
}
