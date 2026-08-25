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

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _brandGold = Color(0xFFFFC800);
  static const _darkSurface = Color(0xEE12131A);

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

  @override
  void initState() {
    super.initState();
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
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppConfig.welcomeAsset),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Modern Dark Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.25),
                  Colors.black.withOpacity(0.55),
                  const Color(0xFF0A0B10).withOpacity(0.92),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Main Content
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 280),
                  // START Button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: _ready
                          ? [
                              BoxShadow(
                                color: AppConfig.primaryColor.withOpacity(0.55),
                                blurRadius: 30,
                                offset: const Offset(0, 8),
                              )
                            ]
                          : [],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 70, vertical: 24),
                        backgroundColor: _ready
                            ? AppConfig.primaryColor
                            : const Color(0xFF2A2C38),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFF1E202B).withOpacity(0.8),
                        disabledForegroundColor: Colors.white38,
                        elevation: _ready ? 12 : 0,
                        side: BorderSide(
                          color: _ready
                              ? _brandGold
                              : Colors.white.withOpacity(0.12),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _ready ? _startSession : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_checking) ...[
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 14),
                          ] else if (_ready) ...[
                            const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 28),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _checking ? 'MEMERIKSA...' : 'START',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Modern Preflight Panel
                  _buildPreflightPanel(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 75,
        decoration: BoxDecoration(
          color: const Color(0xEE0D0E14),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _checking
                        ? _brandGold
                        : (_ready ? const Color(0xFF00E676) : Colors.redAccent),
                    boxShadow: [
                      BoxShadow(
                        color: _checking
                            ? _brandGold.withOpacity(0.6)
                            : (_ready
                                ? const Color(0xFF00E676).withOpacity(0.6)
                                : Colors.redAccent.withOpacity(0.6)),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${AppConfig.boxTitle} • ${_checking ? 'Memeriksa Sistem...' : (_ready ? 'Siap Digunakan' : 'Perhatian Diperlukan')}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const AppCloseButton(
              margin: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreflightPanel() {
    return Container(
      width: 480,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _ready
              ? const Color(0xFF00E676).withOpacity(0.3)
              : (_checking
                  ? _brandGold.withOpacity(0.35)
                  : Colors.redAccent.withOpacity(0.4)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 32,
            offset: const Offset(0, 12),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _checking
                          ? _brandGold.withOpacity(0.15)
                          : (_ready
                              ? const Color(0xFF00E676).withOpacity(0.15)
                              : Colors.redAccent.withOpacity(0.15)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _checking
                          ? Icons.sync_rounded
                          : (_ready
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded),
                      color: _checking
                          ? _brandGold
                          : (_ready
                              ? const Color(0xFF00E676)
                              : Colors.redAccent),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _checking
                            ? 'Pemeriksaan Sistem'
                            : (_ready
                                ? 'Semua Komponen Siap'
                                : 'Sistem Belum Siap'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!_checking)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _runPreflight,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1), width: 1),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.redAccent.withOpacity(0.3), width: 1),
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
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!_checking) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.08),
            ),
            const SizedBox(height: 12),
            ..._checkOrder.map(_buildCheckRow),
          ],
        ],
      ),
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
      statusColor = _brandGold;
      statusText = 'Mencari...';
    } else {
      statusColor = required ? Colors.redAccent : _brandGold;
      statusText = message;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok
              ? Colors.white.withOpacity(0.05)
              : statusColor.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: ok ? Colors.white70 : statusColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
