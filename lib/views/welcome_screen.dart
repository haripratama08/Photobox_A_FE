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
  static const _darkOrange = Color(0xFF5A1707);

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
    'camera': 'Kamera',
    'camera_port': 'Konfigurasi port kamera',
    'printer': 'Printer',
    'storage': 'Penyimpanan foto',
    'frames': 'Folder frame',
    'whatsapp': 'WhatsApp',
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
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppConfig.welcomeAsset),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  _darkOrange.withOpacity(0.10),
                  _darkOrange.withOpacity(0.72),
                ],
                stops: const [0.0, 0.58, 1.0],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 360),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 60, vertical: 25),
                    backgroundColor:
                        _ready ? AppConfig.primaryColor : Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _darkOrange.withOpacity(0.78),
                    disabledForegroundColor: Colors.white70,
                    elevation: _ready ? 10 : 0,
                    shadowColor: AppConfig.primaryColor.withOpacity(0.55),
                    side: BorderSide(
                      color: _ready ? _brandGold : _brandGold.withOpacity(0.38),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _ready ? _startSession : null,
                  child: Text(
                    _checking ? 'MEMERIKSA...' : 'START',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildPreflightPanel(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: _darkOrange.withOpacity(0.94),
          border: Border(
            top: BorderSide(color: _brandGold.withOpacity(0.42)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.circle,
                    color: _ready ? Colors.greenAccent : _brandGold, size: 16),
                const SizedBox(width: 10),
                Text(
                  '${AppConfig.boxTitle} • ${_ready ? 'Siap digunakan' : 'Menunggu pemeriksaan'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
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
      width: 430,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _darkOrange.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brandGold.withOpacity(0.48)),
        boxShadow: [
          BoxShadow(
            color: _darkOrange.withOpacity(0.42),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _checking
                    ? Icons.sync_rounded
                    : (_ready
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded),
                color: _checking
                    ? _brandGold
                    : (_ready ? Colors.greenAccent : _brandGold),
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _checking
                      ? 'Memeriksa kesiapan photobox...'
                      : (_ready
                          ? 'Semua komponen wajib siap'
                          : 'Photobox belum siap digunakan'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!_checking)
                IconButton(
                  tooltip: 'Periksa lagi',
                  onPressed: _runPreflight,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white70, size: 21),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
          if (!_checking) ...[
            const Divider(color: Colors.white12, height: 16),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: ok
                ? Colors.greenAccent
                : (required ? Colors.redAccent : _brandGold),
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _checkLabels[key] ?? key,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Flexible(
            child: Text(
              check['message']?.toString() ?? 'Tidak ada status',
              style: TextStyle(
                color: ok ? Colors.greenAccent : Colors.white54,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
