import 'package:flutter/material.dart';

class DisclaimerBanner extends StatefulWidget {
  const DisclaimerBanner({super.key});

  @override
  State<DisclaimerBanner> createState() => _DisclaimerBannerState();
}

class _DisclaimerBannerState extends State<DisclaimerBanner> {
  bool isVisible = true;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: const Color.fromARGB(255, 67, 83, 63),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: const Color.fromARGB(255, 41, 173, 14),
            size: 22,
          ),

          const SizedBox(width: 10),

          // text
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: const Color.fromARGB(255, 74, 179, 78),
                  fontSize: 13,
                  height: 1.4,
                ),
                children: const [
                  TextSpan(
                    text: "Demo App: ",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        "This is a UI/UX prototype. Features like camera access, SIM detection, and device security actions require native mobile APIs.",
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // close button
          GestureDetector(
            onTap: () {
              setState(() {
                isVisible = false;
              });
            },
            child: Icon(
              Icons.close,
              size: 20,
              color: const Color.fromARGB(255, 38, 159, 14),
            ),
          ),
        ],
      ),
    );
  }
}
