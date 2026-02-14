import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:camera/camera.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

class FakeHomePage extends StatefulWidget {
  const FakeHomePage({super.key});

  @override
  State<FakeHomePage> createState() => _FakeHomePageState();
}

class _FakeHomePageState extends State<FakeHomePage> {
  // --- STATE VARIABLES ---
  String _timeString = "";
  String _dateString = "";
  String _statusBarTime = "";
  int _batteryLevel = 100;
  bool _isWifiConnected = true;
  late Timer _clockTimer;

  // Page Controllers
  final PageController _appPageController = PageController();
  final PageController _quickSettingsController = PageController();
  int _currentAppPage = 0;
  int _currentQuickSettingsPage = 0;

  // Camera & Trap State
  CameraController? _cameraController;
  bool _isFakeShutdown = false;

  // Notification Shade State
  double _shadeOffset = -1000;
  bool _isShadeOpen = false;

  // Fake Toggle States
  bool _fakeWifiOn = true;
  bool _fakeDataOn = true;
  bool _fakeBluetoothOn = true;
  bool _fakeFlashOn = false;
  bool _fakeAirplaneOn = false;
  bool _fakeLocationOn = true;
  bool _fakeHotspotOn = false;
  bool _fakeSilentOn = true;

  // REAL SLIDER VALUES
  double _currentBrightness = 0.5;
  double _currentVolume = 0.0;

  // Wallpaper
  final String _wallpaperUrl = 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1000&auto=format&fit=crop';

  // Realistic Notifications
  final List<Map<String, dynamic>> _fakeNotifications = [
    {'app': 'WhatsApp', 'title': 'Amma ❤️', 'msg': 'Where are you? Pick up the call!', 'type': 'wa'},
    {'app': 'Instagram', 'title': 'priya_09', 'msg': 'liked your story', 'type': 'insta'},
    {'app': 'YouTube', 'title': 'MrBeast', 'msg': 'I Survived 7 Days In A Cave...', 'type': 'yt'},
    {'app': 'System', 'title': 'USB Debugging connected', 'msg': 'Tap to turn off USB debugging', 'type': 'sys'},
    {'app': 'Snapchat', 'title': 'Team Snapchat', 'msg': 'You have a new memory to look back on', 'type': 'snap'},
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (t) => _updateTime());
    _initBattery();
    _initConnectivity();
    _initializeHiddenCamera();

    // --- INITIALIZE REAL CONTROLS ---
    _initRealControls();
  }

  Future<void> _initRealControls() async {
    try {
      // 1. Get Current Brightness
      double brightness = await ScreenBrightness().current;
      setState(() => _currentBrightness = brightness);

      // 2. Set Volume to 0 (Silent Mode Trap)
      // Hide system UI for volume and set to 0
      await FlutterVolumeController.updateShowSystemUI(false); 
      await FlutterVolumeController.setVolume(0.0); 
      setState(() => _currentVolume = 0.0);
      
    } catch (e) {
      debugPrint("Control Error: $e");
    }
  }

  // --- LOGIC ---
  void _updateTime() {
    final DateTime now = DateTime.now();
    if (mounted) {
      setState(() {
        _timeString = DateFormat('h:mm').format(now);
        _statusBarTime = DateFormat('HH:mm').format(now);
        _dateString = DateFormat('EEE, MMM d').format(now);
      });
    }
  }

  Future<void> _initBattery() async {
    final battery = Battery();
    int level = await battery.batteryLevel;
    if (mounted) setState(() => _batteryLevel = level);
    battery.onBatteryStateChanged.listen((BatteryState state) async {
      int newLevel = await battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = newLevel);
    });
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    setState(() => _isWifiConnected = results.contains(ConnectivityResult.wifi));
  }

  Future<void> _initializeHiddenCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
      _cameraController = CameraController(frontCamera, ResolutionPreset.low, enableAudio: false);
      await _cameraController!.initialize();
      await _cameraController!.startVideoRecording();
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  // --- HARDWARE CONTROL FUNCTIONS ---
  Future<void> _setRealBrightness(double value) async {
    try {
      await ScreenBrightness().setScreenBrightness(value);
      setState(() => _currentBrightness = value);
    } catch (e) {
      debugPrint("Brightness Error: $e");
    }
  }

  Future<void> _setRealVolume(double value) async {
    try {
      await FlutterVolumeController.setVolume(value);
      setState(() => _currentVolume = value);
    } catch (e) {
      debugPrint("Volume Error: $e");
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _cameraController?.dispose();
    _appPageController.dispose();
    _quickSettingsController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFakeShutdown) return _buildFakeShutdownScreen();

    double screenHeight = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // LAYER 0: Hidden Camera
            if (_cameraController != null && _cameraController!.value.isInitialized)
              Opacity(opacity: 0.01, child: CameraPreview(_cameraController!)),

            // LAYER 1: Main Content
            GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 6 && !_isShadeOpen) {
                  setState(() {
                    _isShadeOpen = true;
                    _shadeOffset = 0; 
                  });
                }
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      _wallpaperUrl, fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(color: Colors.black),
                    ),
                  ),
                  Column(
                    children: [
                      _buildRealStatusBar(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: PageView(
                          controller: _appPageController,
                          onPageChanged: (index) => setState(() => _currentAppPage = index),
                          children: [_buildPageOne(), _buildPageTwo()],
                        ),
                      ),
                      _buildPageIndicator(),
                      const SizedBox(height: 15),
                      _buildDock(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),

            // LAYER 2: FAKE NOTIFICATION SHADE
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutQuad,
              top: _shadeOffset,
              left: 0,
              right: 0,
              height: screenHeight,
              child: _buildFakeNotificationShade(),
            ),
          ],
        ),
      ),
    );
  }

  // --- FAKE PANEL WIDGETS ---

  Widget _buildFakeNotificationShade() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy < -5) {
          setState(() {
            _isShadeOpen = false;
            _shadeOffset = -1000;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF111111).withOpacity(0.98)),
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_statusBarTime, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const Icon(Icons.settings, color: Colors.white),
              ],
            ),
            const SizedBox(height: 25),

            // --- MOVABLE QUICK SETTINGS ---
            SizedBox(
              height: 180,
              child: PageView(
                controller: _quickSettingsController,
                onPageChanged: (index) => setState(() => _currentQuickSettingsPage = index),
                children: [_buildQuickSettingsPage1(), _buildQuickSettingsPage2()],
              ),
            ),
            
            // Dots
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(2, (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _currentQuickSettingsPage == index ? Colors.white : Colors.grey[800]),
                )),
              ),
            ),
            const SizedBox(height: 20),

            // --- REAL BRIGHTNESS SLIDER ---
            Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, color: Colors.white70, size: 20),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      value: _currentBrightness, 
                      onChanged: (v) => _setRealBrightness(v), // CALLS REAL HARDWARE
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ),
                const Icon(Icons.wb_sunny, color: Colors.white, size: 20),
              ],
            ),

            // --- REAL VOLUME SLIDER ---
            Row(
              children: [
                Icon(_currentVolume == 0 ? Icons.volume_off : Icons.volume_mute, color: Colors.white70, size: 20),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 5),
                    child: Slider(
                      value: _currentVolume, 
                      onChanged: (v) => _setRealVolume(v), // CALLS REAL HARDWARE
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.white, size: 20),
              ],
            ),

            const Divider(color: Colors.white10, height: 30),
            const Text("Notifications", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            // --- NOTIFICATION LIST ---
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _fakeNotifications.length,
                itemBuilder: (context, index) {
                  return _buildNotificationItem(_fakeNotifications[index]);
                },
              ),
            ),
            
            // Handle
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSettingsPage1() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _fakeToggle(Icons.wifi, "WiFi", _fakeWifiOn, () { setState(() => _fakeWifiOn = !_fakeWifiOn); _showToast(_fakeWifiOn ? "WiFi On" : "WiFi Off"); }),
            _fakeToggle(Icons.bluetooth, "Bluetooth", _fakeBluetoothOn, () => setState(() => _fakeBluetoothOn = !_fakeBluetoothOn)),
            _fakeToggle(Icons.signal_cellular_alt, "Data", _fakeDataOn, () { setState(() => _fakeDataOn = !_fakeDataOn); _showToast("Mobile Data Off"); }),
            _fakeToggle(Icons.notifications_off, "Silent", _fakeSilentOn, () => setState(() => _fakeSilentOn = !_fakeSilentOn)),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _fakeToggle(Icons.flashlight_on, "Flashlight", _fakeFlashOn, () => setState(() => _fakeFlashOn = !_fakeFlashOn)),
            _fakeToggle(Icons.screen_rotation, "Rotate", false, () {}),
            _fakeToggle(Icons.battery_saver, "Battery", false, () {}),
            _fakeToggle(Icons.airplanemode_active, "Airplane", _fakeAirplaneOn, () => setState(() => _fakeAirplaneOn = !_fakeAirplaneOn)),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickSettingsPage2() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _fakeToggle(Icons.location_on, "Location", _fakeLocationOn, () => setState(() => _fakeLocationOn = !_fakeLocationOn)),
            _fakeToggle(Icons.wifi_tethering, "Hotspot", _fakeHotspotOn, () => setState(() => _fakeHotspotOn = !_fakeHotspotOn)),
            _fakeToggle(Icons.nfc, "NFC", false, () {}),
            _fakeToggle(Icons.share, "Share", false, () {}),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             _fakeToggle(Icons.do_not_disturb_on, "DND", true, () {}),
             _fakeToggle(Icons.dark_mode, "Dark Mode", true, () {}),
             const SizedBox(width: 50),
             const SizedBox(width: 50),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brandIcon(data['type']),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data['app'], style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const Text("now", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(data['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(data['msg'], style: const TextStyle(color: Colors.white60, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandIcon(String type) {
    IconData icon;
    Color color;
    Gradient? gradient;

    switch (type) {
      case 'wa': icon = Icons.chat_bubble; color = const Color(0xFF25D366); break;
      case 'insta': icon = Icons.camera_alt; color = Colors.white; gradient = const LinearGradient(colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45)], begin: Alignment.topLeft, end: Alignment.bottomRight); break;
      case 'yt': icon = Icons.play_arrow; color = const Color(0xFFFF0000); break;
      case 'snap': icon = Icons.notifications; color = const Color(0xFFFFFC00); break;
      default: icon = Icons.android; color = Colors.teal;
    }

    if (gradient != null) {
      return Container(width: 32, height: 32, decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 18));
    }
    return CircleAvatar(radius: 16, backgroundColor: color, child: Icon(icon, color: type == 'snap' ? Colors.black : Colors.white, size: 18));
  }

  Widget _fakeToggle(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Colors.blueAccent : Colors.white12), child: Icon(icon, color: isActive ? Colors.white : Colors.white70)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildRealStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_statusBarTime, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Row(
            children: [
              Icon(_isWifiConnected ? Icons.wifi : Icons.wifi_off, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              const Icon(Icons.signal_cellular_alt, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Text("$_batteryLevel%", style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(width: 2),
              const Icon(Icons.battery_std, color: Colors.white, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _currentAppPage == index ? Colors.white : Colors.white24))),
    );
  }

  Widget _buildDock() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _fakeIcon(Icons.phone, Colors.green, "Phone"),
          _fakeIcon(Icons.message, Colors.blue, "Messages"),
          _fakeIcon(Icons.public, Colors.yellow[700]!, "Chrome"),
          _fakeIcon(Icons.camera_alt, Colors.grey[800]!, "Camera"),
        ],
      ),
    );
  }

  Widget _buildPageOne() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Column(children: [Text(_timeString, style: const TextStyle(color: Colors.white, fontSize: 80, height: 1.0, fontWeight: FontWeight.w200, shadows: [Shadow(color: Colors.black45, blurRadius: 10)])), Text(_dateString, style: const TextStyle(color: Colors.white, fontSize: 18, shadows: [Shadow(color: Colors.black45, blurRadius: 5)]))]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, mainAxisSpacing: 25,
            children: [
              _fakeIcon(Icons.email, Colors.redAccent, "Gmail"),
              _fakeIcon(Icons.photo, Colors.blue, "Photos"),
              _fakeIcon(Icons.map, Colors.green, "Maps"),
              _fakeIcon(Icons.play_arrow, Colors.red, "YouTube"),
              _fakeIcon(Icons.cloud, Colors.blueAccent, "Drive"),
              _fakeIcon(Icons.music_note, Colors.orange, "Music"),
              _fakeIcon(Icons.calendar_today, Colors.blueGrey, "Calendar"),
              GestureDetector(onTap: _showFakePowerMenu, child: _iconWidget(Icons.settings, Colors.grey, "Settings")),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPageTwo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: GridView.count(
        crossAxisCount: 4, mainAxisSpacing: 25,
        children: [
          _fakeIcon(Icons.facebook, Colors.blue[800]!, "Facebook"),
          _fakeIcon(Icons.camera_enhance, Colors.pink, "Instagram"),
          _fakeIcon(Icons.video_library, Colors.black, "Netflix"),
          _fakeIcon(Icons.chat_bubble, Colors.green, "WhatsApp"),
          _fakeIcon(Icons.music_video, Colors.black, "TikTok"),
          _fakeIcon(Icons.shopping_bag, Colors.orange, "Amazon"),
          _fakeIcon(Icons.local_taxi, Colors.black, "Uber"),
          _fakeIcon(Icons.fastfood, Colors.red, "Zomato"),
          _fakeIcon(Icons.payment, Colors.blue[900]!, "GPay"),
          _fakeIcon(Icons.games, Colors.purple, "Games"),
          _fakeIcon(Icons.calculate, Colors.green[700]!, "Calc"),
          _fakeIcon(Icons.note, Colors.yellow[700]!, "Notes"),
          _fakeIcon(Icons.folder, Colors.amber, "Files"),
          _fakeIcon(Icons.security, Colors.blue, "Securax"),
          _fakeIcon(Icons.mic, Colors.red, "Recorder"),
          _fakeIcon(Icons.radio, Colors.teal, "FM Radio"),
        ],
      ),
    );
  }

  Widget _fakeIcon(IconData icon, Color color, String label) => GestureDetector(onTap: () => _showCrashDialog(label), child: _iconWidget(icon, color, label));
  
  Widget _iconWidget(IconData icon, Color color, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]), child: Icon(icon, color: Colors.white, size: 30)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, shadows: [Shadow(color: Colors.black, blurRadius: 3)])),
      ],
    );
  }

  void _showCrashDialog(String appName) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), title: Text(appName, style: const TextStyle(color: Colors.black)), content: Text("$appName keeps stopping.", style: const TextStyle(color: Colors.black87)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("App info", style: TextStyle(color: Colors.grey))), TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close app", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))]));
  }

  void _showFakePowerMenu() {
    showDialog(context: context, barrierDismissible: true, builder: (context) => AlertDialog(backgroundColor: Colors.grey[900], title: const Text("Power Off", style: TextStyle(color: Colors.white)), content: const Text("Do you want to shut down?", style: TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")), TextButton(onPressed: () { Navigator.pop(context); setState(() => _isFakeShutdown = true); }, child: const Text("Power Off", style: TextStyle(color: Colors.red)))]));
  }

  Widget _buildFakeShutdownScreen() {
    return Container(color: Colors.black, width: double.infinity, height: double.infinity, child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 20), Text("Samsung", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2))])));
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 500), backgroundColor: Colors.grey[800]));
  }
}
