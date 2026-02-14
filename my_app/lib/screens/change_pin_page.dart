import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePinPage extends StatefulWidget {
  final bool isRealPin;
  const ChangePinPage({super.key, required this.isRealPin});

  @override
  State<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<ChangePinPage> {
  final _controller = TextEditingController();

  Future<void> _savePin() async {
    if (_controller.text.length != 4) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.isRealPin ? 'real_pin' : 'fake_pin', _controller.text);
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(title: Text(widget.isRealPin ? "Set Real PIN" : "Set Trap PIN")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Enter New 4-Digit PIN", labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _savePin, child: const Text("Save PIN")),
          ],
        ),
      ),
    );
  }
}