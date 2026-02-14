import 'package:flutter/material.dart';

import '../screens/menu_add_email_page.dart';
import '../services/alert_recipient_service.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _service = AlertRecipientService();
  bool _loading = true;
  bool _sendingTest = false;
  bool _sendingLatest = false;
  List<String> _emails = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final items = await _service.listRecipients();
      if (!mounted) return;
      setState(() => _emails = items);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load email list from backend')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddEmailPage() async {
    final navigator = Navigator.of(context);
    navigator.pop(); // close drawer first

    final result = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const MenuAddEmailPage()),
    );

    if (!mounted) return;
    await _refresh();
    if (!mounted || result == null) return;

    final msg = result == 'exists' ? 'Email already added' : 'Done';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _removeEmail(String email) async {
    try {
      await _service.removeRecipient(email);
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remove failed: $e')),
      );
    }
  }

  Future<void> _sendTestEmail() async {
    if (_sendingTest) return;
    setState(() => _sendingTest = true);
    try {
      await _service.sendTestEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test email sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test email failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  Future<void> _sendLatestPhoto() async {
    if (_sendingLatest) return;
    setState(() => _sendingLatest = true);
    try {
      await _service.sendLatestEvidence();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latest photo sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send latest failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingLatest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white12),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.menu, size: 20, color: Colors.greenAccent),
                  SizedBox(width: 8),
                  Text(
                    'SECURAX MENU',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Text(
                'Actions',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _menuActionTile(
              icon: Icons.email_outlined,
              title: 'Add Email',
              subtitle: 'Send captured evidence to this address',
              onTap: _openAddEmailPage,
            ),
            _menuActionTile(
              icon: Icons.send_outlined,
              title: 'Test Email',
              subtitle: 'Send test message now',
              loading: _sendingTest,
              onTap: _sendingTest ? null : _sendTestEmail,
            ),
            _menuActionTile(
              icon: Icons.photo_camera_back_outlined,
              title: 'Send Latest Photo Now',
              subtitle: 'Email latest captured image',
              loading: _sendingLatest,
              onTap: _sendingLatest ? null : _sendLatestPhoto,
            ),
            const Divider(height: 18, thickness: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Alert Recipients',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_emails.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No alert email added yet'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: _emails.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final email = _emails[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.alternate_email, size: 20),
                        title: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _removeEmail(email),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _menuActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      minLeadingWidth: 18,
      trailing: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right, size: 20, color: Colors.white54),
      onTap: onTap,
    );
  }
}
