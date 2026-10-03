import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photobox_pro/config/app_config.dart';
import 'package:photobox_pro/services/socket_services.dart';
import 'package:photobox_pro/widgets/app_close_button.dart';
import 'package:provider/provider.dart';

import 'registration_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _checkOrder = [
    'api',
    'camera',
    'camera_port',
    'printer',
    'storage',
    'frames',
    'whatsapp'
  ];

  static const _checkLabels = {
    'api': 'API / Port',
    'camera': 'Kamera Utama',
    'camera_port': 'Port Kamera',
    'printer': 'Printer Foto',
    'storage': 'Penyimpanan Foto',
    'frames': 'Folder Frame',
    'whatsapp': 'WhatsApp Service',
  };

  static const _checkIcons = {
    'api': Icons.dns_rounded,
    'camera': Icons.camera_alt_rounded,
    'camera_port': Icons.settings_input_hdmi_rounded,
    'printer': Icons.print_rounded,
    'storage': Icons.folder_special_rounded,
    'frames': Icons.photo_library_rounded,
    'whatsapp': Icons.chat_rounded,
  };

  Timer? _preflightTimeout;
  Timer? _preflightRetry;
  Map<String, dynamic> _checks = {};
  bool _checking = true;
  bool _ready = false;
  String? _error;
  bool _showDetails = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool get _isBoxA => AppConfig.boxId == 'box-a';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _runPreflight());
  }

  void _runPreflight() {
    if (!mounted) return;
    _preflightTimeout?.cancel();
    setState(() {
      _checking = true;
      _ready = false;
      _error = null;
    });

    final socket = context.read<SocketService>();
    socket.once('preflight-result', (data) {
      if (!mounted) return;
      _preflightTimeout?.cancel();
      final payload =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final checks = payload['checks'] is Map
          ? Map<String, dynamic>.from(payload['checks'] as Map)
          : <String, dynamic>{};
      setState(() {
        _checks = checks;
        _checking = false;
        _ready = payload['ok'] == true;
        _error = payload['error'] as String?;
      });
      final printer = checks['printer'] is Map
          ? Map<String, dynamic>.from(checks['printer'] as Map)
          : <String, dynamic>{};
      _preflightRetry?.cancel();
      if (printer['searching'] == true) {
        _preflightRetry = Timer(const Duration(seconds: 3), _runPreflight);
      }
    });
    socket.emit('preflight-check');

    _preflightTimeout = Timer(const Duration(seconds: 8), () {
      if (!mounted || !_checking) return;
      setState(() {
        _checking = false;
        _ready = false;
        _error = 'API tidak merespons pemeriksaan kesiapan.';
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _preflightTimeout?.cancel();
    _preflightRetry?.cancel();
    super.dispose();
  }

  void _startSession() {
    if (!_ready || _checking) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _isBoxA ? const Color(0xFFC71C00) : const Color(0xFF92E0FF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;

          // Safe Zone Calculation: Zero Collision with background graphics
          final double safeTop = _isBoxA
              ? (240.0 / 800.0) * screenHeight
              : (150.0 / 900.0) * screenHeight;

          final double safeBottom = _isBoxA
              ? (645.0 / 800.0) * screenHeight
              : (780.0 / 900.0) * screenHeight;

          final double safeHeight = safeBottom - safeTop;

          return Stack(
            children: [
              // 1. Pristine Graphic Background Asset
              Positioned.fill(
                child: Image.asset(
                  AppConfig.welcomeAsset,
                  fit: BoxFit.fill,
                ),
              ),

              // 2. Interactive UI strictly inside Vertical Safe Zone
              Positioned(
                top: safeTop,
                left: 0,
                right: 0,
                height: safeHeight,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStartButton(),
                          const SizedBox(height: 18),
                          _buildPreflightPanel(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Discreet Floating AppCloseButton
              Positioned(
                top: 20,
                right: 20,
                child: AppCloseButton(
                  margin: EdgeInsets.zero,
                  backgroundColor: Colors.black.withOpacity(0.45),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStartButton() {
    final Color btnBg = _ready
        ? (_isBoxA ? const Color(0xFFF5C500) : const Color(0xFF0039C8))
        : const Color(0xFF2A2C38);

    final Color btnFg = _isBoxA ? const Color(0xFF420700) : Colors.white;

    final Color borderColor = _ready
        ? (_isBoxA ? const Color(0xFFFFF2A3) : Colors.white.withOpacity(0.75))
        : Colors.white.withOpacity(0.15);

    final Color shadowColor = _ready
        ? (_isBoxA
            ? const Color(0xFFF5C500).withOpacity(0.55)
            : const Color(0xFF0039C8).withOpacity(0.45))
        : Colors.transparent;

    return ScaleTransition(
      scale: _ready ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(45),
          boxShadow: _ready
              ? [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 32,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 22),
            backgroundColor: btnBg,
            foregroundColor: btnFg,
            disabledBackgroundColor: const Color(0xFF1E202B).withOpacity(0.85),
            disabledForegroundColor: Colors.white38,
            elevation: _ready ? 14 : 0,
            side: BorderSide(color: borderColor, width: 2.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(45),
            ),
          ),
          onPressed: _ready ? _startSession : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_checking) ...[
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: btnFg,
                  ),
                ),
                const SizedBox(width: 14),
              ] else if (_ready) ...[
                Icon(
                  Icons.play_arrow_rounded,
                  color: btnFg,
                  size: 34,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                _checking ? 'MEMERIKSA...' : 'START',
                style: TextStyle(
                  color: btnFg,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreflightPanel() {
    final Color panelBg = _isBoxA
        ? const Color(0xDD300500)
        : const Color(0xEEFFFFFF);

    final Color panelBorder = _isBoxA
        ? const Color(0x55F5C500)
        : const Color(0x350039C8);

    final Color titleColor = _isBoxA ? Colors.white : const Color(0xFF0039C8);
    final Color subtitleColor = _isBoxA
        ? const Color(0xFFFFF0C2).withOpacity(0.8)
        : const Color(0xFF0039C8).withOpacity(0.75);

    return Container(
      width: 500,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _ready
              ? const Color(0xFF00E676).withOpacity(0.4)
              : (_checking
                  ? const Color(0xFFFFC800).withOpacity(0.4)
                  : Colors.redAccent.withOpacity(0.4)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Badge & Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _checking
                            ? const Color(0xFFFFC800).withOpacity(0.18)
                            : (_ready
                                ? const Color(0xFF00E676).withOpacity(0.18)
                                : Colors.redAccent.withOpacity(0.18)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _checking
                            ? Icons.sync_rounded
                            : (_ready
                                ? Icons.verified_rounded
                                : Icons.warning_amber_rounded),
                        color: _checking
                            ? const Color(0xFFFFC800)
                            : (_ready
                                ? const Color(0xFF00E676)
                                : Colors.redAccent),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _checking
                                ? 'Pemeriksaan Sistem'
                                : (_ready
                                    ? 'Semua Komponen Siap'
                                    : 'Sistem Belum Siap'),
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            _checking
                                ? 'Memeriksa perangkat & layanan...'
                                : (_ready
                                    ? 'Semua modul beroperasi normal'
                                    : 'Periksa komponen berlabel merah/kuning'),
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _showDetails
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: titleColor.withOpacity(0.8),
                      size: 22,
                    ),
                    onPressed: () => setState(() => _showDetails = !_showDetails),
                    tooltip: 'Detail Status',
                  ),
                  if (!_checking)
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: titleColor.withOpacity(0.8),
                        size: 20,
                      ),
                      onPressed: _runPreflight,
                      tooltip: 'Periksa Ulang',
                    ),
                ],
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Quick Hardware Summary Chips (Always Visible)
          if (!_checking) ...[
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: titleColor.withOpacity(0.12),
            ),
            const SizedBox(height: 8),
            _buildQuickHardwareChips(),
          ],

          // Expandable Detailed Checklist Rows
          if (!_checking && _showDetails) ...[
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: titleColor.withOpacity(0.12),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                children: _checkOrder.map(_buildCheckRow).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickHardwareChips() {
    final primaryChecks = ['camera', 'printer', 'api', 'storage'];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: primaryChecks.map((key) {
        final check = _checks[key] is Map
            ? Map<String, dynamic>.from(_checks[key] as Map)
            : <String, dynamic>{};
        final ok = check['ok'] == true;
        final icon = _checkIcons[key] ?? Icons.check_circle_outline;
        final label = _checkLabels[key] ?? key;

        final Color dotColor =
            ok ? const Color(0xFF00E676) : Colors.redAccent;
        final Color textColor =
            _isBoxA ? Colors.white70 : const Color(0xFF0039C8).withOpacity(0.85);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (_isBoxA ? Colors.white : const Color(0xFF0039C8))
                .withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: dotColor.withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCheckRow(String key) {
    final check = _checks[key] is Map
        ? Map<String, dynamic>.from(_checks[key] as Map)
        : <String, dynamic>{};
    final ok = check['ok'] == true;
    final required = check['required'] != false;
    final isSearching = check['searching'] == true;
    final icon = _checkIcons[key] ?? Icons.widgets_rounded;
    final label = _checkLabels[key] ?? key;
    final message = check['message']?.toString() ?? 'Tidak ada status';

    Color statusColor;
    String statusText;
    if (ok) {
      statusColor = const Color(0xFF00E676);
      statusText = message.isNotEmpty && message != 'OK' ? message : 'Ready';
    } else if (isSearching) {
      statusColor = const Color(0xFFFFC800);
      statusText = 'Mencari...';
    } else {
      statusColor = required ? Colors.redAccent : const Color(0xFFFFC800);
      statusText = message;
    }

    final Color textColor =
        _isBoxA ? Colors.white.withOpacity(0.9) : const Color(0xFF0039C8);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (_isBoxA ? Colors.white : const Color(0xFF0039C8))
            .withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok
              ? Colors.transparent
              : statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: ok ? statusColor : statusColor, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
