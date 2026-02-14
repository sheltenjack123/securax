import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/evidence_service.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _realPin = "1234";
  String _fakePin = "9999";
  String _enteredPin = "";
  bool _isLoading = true;

  Future<void> _handleFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('capture_on_wrong_pin') ?? false;
    if (!enabled) return;

    final current = (prefs.getInt('failed_attempts_count') ?? 0) + 1;
    await prefs.setInt('failed_attempts_count', current);

    // Capture evidence in the background; do not block the UI thread.
    await EvidenceService().captureAndUpload(reason: "app_lock_wrong_pin");
  }

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final prefs = await SharedPreferences.getInstance();
    // Default OFF: this app should not block launch with an extra PIN unless user enabled it.
    if (prefs.getBool('is_lock_enabled') != true) {
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    setState(() {
      _realPin = prefs.getString('real_pin') ?? "1234";
      _fakePin = prefs.getString('fake_pin') ?? "9999";
      _isLoading = false;
    });
  }

  void _handlePin(String val) {
    setState(() {
      if (_enteredPin.length < 4) _enteredPin += val;

      if (_enteredPin.length == 4) {
        if (_enteredPin == _realPin) {
          // Successful unlock: reset failed attempts counter.
          unawaited(SharedPreferences.getInstance().then((p) => p.setInt('failed_attempts_count', 0)));
          Navigator.pushReplacementNamed(context, '/home');
        } else if (_enteredPin == _fakePin) {
          unawaited(SharedPreferences.getInstance().then((p) => p.setInt('failed_attempts_count', 0)));
          Navigator.pushReplacementNamed(context, '/fake_home');
        } else {
          HapticFeedback.heavyImpact();
          _enteredPin = "";
          unawaited(_handleFailedAttempt());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Incorrect PIN"),
              backgroundColor: Colors.red,
              duration: Duration(milliseconds: 500),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Colors.black);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            const Icon(Icons.lock_outline, size: 60, color: Colors.greenAccent),
            const SizedBox(height: 20),
            const Text(
              "Securax Locked",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Enter PIN to access",
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _enteredPin.length
                        ? Colors.greenAccent
                        : Colors.white12,
                    boxShadow: index < _enteredPin.length
                        ? [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.4),
                              blurRadius: 10,
                            ),
                          ]
                        : [],
                  ),
                );
              }),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Wrap(
                spacing: 25,
                runSpacing: 25,
                alignment: WrapAlignment.center,
                children: [
                  ...List.generate(9, (i) => _numBtn("${i + 1}")),
                  const SizedBox(width: 75),
                  _numBtn("0"),
                  _deleteBtn(),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _numBtn(String label) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _handlePin(label);
      },
      child: Container(
        width: 75,
        height: 75,
        decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
        child: Center(
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 24)),
        ),
      ),
    );
  }

  Widget _deleteBtn() {
    return GestureDetector(
      onTap: () {
        if (_enteredPin.isNotEmpty) {
          setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
        }
      },
      child: Container(
        width: 75,
        height: 75,
        color: Colors.transparent,
        child: const Icon(Icons.backspace, color: Colors.white54),
      ),
    );
  }
}
