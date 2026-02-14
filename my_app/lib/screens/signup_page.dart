import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emergencyEmailController = TextEditingController(); // Where alerts go
  bool _isLoading = false;

  Future<void> _signUp() async {
    setState(() => _isLoading = true);

    try {
      // 1. Create User in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Save "Emergency Settings" to Firestore Database
      // We create a document with the User's ID
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text.trim(),
        'emergency_email': _emergencyEmailController.text.trim(), // IMPORTANT
        'created_at': DateTime.now(),
        'device_model': 'Android', // You can get real model later
      });

      // 3. Success! Go to Home
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.message}")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Create Account"), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.security, size: 80, color: Colors.greenAccent),
            const SizedBox(height: 20),
            
            // EMAIL INPUT
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Login Email"),
            ),
            const SizedBox(height: 15),

            // PASSWORD INPUT
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Password"),
            ),
            const SizedBox(height: 15),

            // EMERGENCY EMAIL INPUT (Critical for your feature)
            TextField(
              controller: _emergencyEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Alert Email (Where to send photos)"),
            ),
            const SizedBox(height: 30),

            // SIGN UP BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                onPressed: _isLoading ? null : _signUp,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text("Activate Securax", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
      filled: true,
      fillColor: Colors.grey.shade900,
    );
  }
}
