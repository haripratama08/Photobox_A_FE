import 'package:flutter/material.dart';
import 'package:photobox_pro/config/app_config.dart';
import 'package:window_manager/window_manager.dart';

class AppCloseButton extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;

  const AppCloseButton({
    super.key,
    this.margin = const EdgeInsets.only(right: 16),
    this.backgroundColor,
  });

  Future<void> _confirmClose(BuildContext context) async {
    final shouldClose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Row(
          children: [
            Icon(Icons.power_settings_new_rounded,
                color: Colors.redAccent, size: 30),
            SizedBox(width: 12),
            Text('Tutup Photobox?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Sesi yang sedang berjalan akan dihentikan dan aplikasi ${AppConfig.boxTitle} akan ditutup.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 16,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: const Text('BATAL'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.close_rounded),
            label: const Text(
              'TUTUP APLIKASI',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (shouldClose == true) {
      await windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withValues(alpha: 0.58),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Tooltip(
        message: 'Tutup aplikasi',
        child: IconButton(
          onPressed: () => _confirmClose(context),
          icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
        ),
      ),
    );
  }
}
