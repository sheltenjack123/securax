import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("SETTINGS"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header("General"),
          SwitchListTile(
            title: const Text("Notifications", style: TextStyle(color: Colors.white)),
            value: notifications,
              activeThumbColor: Colors.greenAccent,
            onChanged: (v) => setState(() => notifications = v),
          ),
          
          const Divider(color: Colors.white24),
          _header("Account"),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: const Text("Log Out", style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Delete Account", style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _header(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(t, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
  );
}
