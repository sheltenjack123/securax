import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int step = 0;

  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  bool cameraPermission = false;
  bool locationPermission = false;
  bool smsPermission = false;

  final int totalSteps = 4;

  bool get canProceed {
    if (step == 0) return true;
    if (step == 1) {
      return emailController.text.isNotEmpty &&
          phoneController.text.isNotEmpty;
    }
    if (step == 2) {
      return cameraPermission && locationPermission && smsPermission;
    }
    return true;
  }

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void next() {
    if (step < totalSteps - 1) {
      setState(() => step++);
    } else {
      // TODO: save config + go to home page
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  void back() {
    if (step > 0) setState(() => step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            buildProgress(),
            Expanded(child: buildContent()),
            buildActions(),
          ],
        ),
      ),
    );
  }

  // ---------- Progress Bar ----------

  Widget buildProgress() {
    return Container(
      color: const Color.fromARGB(255, 0, 24, 0),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(totalSteps, (i) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              decoration: BoxDecoration(
                color: i <= step
                    ? const Color.fromARGB(255, 5, 171, 46)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------- Step Content ----------

  Widget buildContent() {
    switch (step) {
      case 0:
        return stepWelcome();
      case 1:
        return stepContact();
      case 2:
        return stepPermissions();
      default:
        return stepDone();
    }
  }

  // ---------- STEP 1 ----------

  Widget stepWelcome() {
    return Container(
      color: const Color.fromARGB(255, 0, 15, 0),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Image.asset(
              'assets/icon/app_icon2.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 20),
            const Text(
              "SECURAX",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 173, 231, 181),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Protect your device with intrusion detection and security alerts.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color.fromARGB(255, 76, 163, 76)),
            ),
            const SizedBox(height: 30),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              children: const [
                FeatureBox(Icons.camera_alt, "Auto Capture"),
                FeatureBox(Icons.sim_card, "SIM Detection"),
                FeatureBox(Icons.location_on, "Location"),
                FeatureBox(Icons.email, "Email Alerts"),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ---------- STEP 2 ----------

  Widget stepContact() {
    return Container(
      color: const Color.fromARGB(255, 0, 15, 0),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Contact Information",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 173, 231, 181),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              cursorColor: const Color.fromARGB(255, 5, 171, 46),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Email",
                labelStyle:
                    const TextStyle(color: Color.fromARGB(255, 182, 189, 183)),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color.fromARGB(255, 5, 171, 46)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              cursorColor: const Color.fromARGB(255, 5, 171, 46),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Phone",
                labelStyle:
                    const TextStyle(color: Color.fromARGB(255, 182, 189, 183)),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color.fromARGB(255, 5, 171, 46)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 162, 229, 209),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Your contact data stays on your device.",
                style: TextStyle(fontSize: 13),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ---------- STEP 3 ----------

  Widget stepPermissions() {
    return Container(
      color: const Color.fromARGB(255, 0, 15, 0),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Grant Permissions",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 173, 231, 181),
              ),
            ),
            const SizedBox(height: 20),
            permTile(
              "Camera Access",
              cameraPermission,
              (v) => setState(() => cameraPermission = v),
            ),
            permTile(
              "Location Access",
              locationPermission,
              (v) => setState(() => locationPermission = v),
            ),
            permTile(
              "SMS & SIM Access",
              smsPermission,
              (v) => setState(() => smsPermission = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget permTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color.fromARGB(255, 3, 54, 16),
        activeTrackColor: const Color.fromARGB(255, 53, 130, 53),
        inactiveThumbColor: Colors.grey,
      ),
    );
  }

  // ---------- STEP 4 ----------
  Widget stepDone() {
    return Container(
      
      padding: const EdgeInsets.all(24),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            color: Color.fromARGB(255, 41, 101, 43),
            size: 80,
          ),
          SizedBox(height: 20),
          Text(
            "You're Protected!",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            "Security monitoring is now active.",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------- Buttons ----------

  Widget buildActions() {
    Color buttonColor = const Color.fromARGB(172, 51, 189, 51);
    Color textColor = Colors.white;

    if (step == 1) {
      if (emailController.text.isNotEmpty && phoneController.text.isNotEmpty) {
        buttonColor = const Color.fromARGB(255, 46, 161, 46);
        textColor = Colors.white;
      } else {
        buttonColor = Colors.grey.shade400;
        textColor = Colors.grey.shade600;
      }
    }

    return Container(
      color: const Color.fromARGB(255, 0, 24, 0),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: textColor,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: canProceed ? next : null,
            child: Text(step == totalSteps - 1 ? "Get Started" : "Continue"),
          ),
          if (step > 0 && step < totalSteps - 1)
            TextButton(
              onPressed: back,
              style: TextButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 32, 125, 32),
                foregroundColor: Colors.white,
              ),
              child: const Text("Back"),
            ),
        ],
      ),
    );
  }
}

// ---------- Small Widget ----------

class FeatureBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const FeatureBox(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color.fromARGB(255, 9, 139, 24)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
