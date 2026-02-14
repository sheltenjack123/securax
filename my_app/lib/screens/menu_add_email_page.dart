import 'package:flutter/material.dart';

import '../services/alert_recipient_service.dart';

class MenuAddEmailPage extends StatefulWidget {
  const MenuAddEmailPage({super.key});

  @override
  State<MenuAddEmailPage> createState() => _MenuAddEmailPageState();
}

class _MenuAddEmailPageState extends State<MenuAddEmailPage> {
  static const _bgStart = Color(0xFF2E3A2B);
  static const _bgMid = Color(0xFF43533F);
  static const _bgEnd = Color(0xFF5A6B56);
  static const _primary = Color(0xFF2F5C35);
  static const _primaryDark = Color(0xFF284D2D);

  final _service = AlertRecipientService();
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _controller.text.trim();
    if (!_service.isValidEmail(email)) {
      setState(() => _error = 'Enter a valid email');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      final status = await _service.addRecipient(email);
      if (!mounted) return;
      Navigator.of(context).pop(status);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().toLowerCase();
      final showInvalid = message.contains('invalid email');
      final showNetwork = message.contains('socketexception') ||
          message.contains('failed host lookup') ||
          message.contains('timed out') ||
          message.contains('timeoutexception');
      setState(
        () => _error = showInvalid
            ? 'Enter a valid email format'
            : showNetwork
                ? 'Cannot reach server. Check backend connection.'
                : 'Could not save email',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add email failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Menu'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _bgStart,
              _bgMid,
              _bgEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add recovery email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use this address to receive critical security alerts.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.86),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x29000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: const Color(0x1A43533F),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Email Address',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B1B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _controller,
                        keyboardType: TextInputType.emailAddress,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'name@example.com',
                          errorText: _error,
                          filled: true,
                          fillColor: const Color(0xFFF4F7F6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _primary,
                              width: 1.3,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _saving ? null : _submit(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _primaryDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Email'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'We will never share your email with third parties.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5C6662),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
