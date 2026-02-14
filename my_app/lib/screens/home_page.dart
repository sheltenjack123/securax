import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../widgets/disclaimer_banner.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("SECURAX"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const DisclaimerBanner(),
            const SizedBox(height: 16),
            
            // Stats Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _statCard(Icons.warning, "Intrusions", "3", Colors.orange),
                  _statCard(Icons.camera_alt, "Evidence", "5", Colors.blue),
                  _statCard(Icons.sim_card, "SIM Changes", "1", Colors.red),
                  _statCard(Icons.access_time, "Last Active", "2h ago", Colors.green),
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            _sectionHeader("Recent Alerts"),
            _alertTile("Wrong PIN Entered", "Front Camera • 10:42 AM", true),
            _alertTile("SIM Card Removed", "Location Recorded • Yesterday", true),
            
            const SizedBox(height: 25),
            _sectionHeader("System Status"),
            _statusTile("Database Encrypted", true),
            _statusTile("Cloud Backup Synced", true),
            _statusTile("Device Admin Active", false),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
      ),
    );
  }

  Widget _alertTile(String title, String sub, bool isHigh) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isHigh ? Colors.red.withOpacity(0.2) : Colors.blue.withOpacity(0.2), shape: BoxShape.circle),
        child: Icon(Icons.notifications_active, color: isHigh ? Colors.red : Colors.blue, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(sub, style: const TextStyle(color: Colors.white54)),
    );
  }

  Widget _statusTile(String title, bool active) {
    return ListTile(
      leading: Icon(active ? Icons.check_circle : Icons.error, color: active ? Colors.green : Colors.orange),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Text(active ? "OK" : "Action Needed", style: TextStyle(color: active ? Colors.green : Colors.orange, fontSize: 12)),
    );
  }
}
