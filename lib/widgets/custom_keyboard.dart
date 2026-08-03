import 'package:flutter/material.dart';

class CustomKeyboard extends StatelessWidget {
  final Function(String) onKeyTap;
  final VoidCallback onBackspace;
  final VoidCallback onClose;

  const CustomKeyboard({
    Key? key,
    required this.onKeyTap,
    required this.onBackspace,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onClose,
                child: const Text(
                  "Tutup Keyboard",
                  style: TextStyle(
                    color: Color(0xff0000cd),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(
                  width: 20), // Memberi sedikit jarak dari tepi kanan
            ],
          ),
          _buildKeyboardRow(['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']),
          _buildKeyboardRow(['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P']),
          _buildKeyboardRow(['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L']),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKey('@', width: 50),
              ...['Z', 'X', 'C', 'V', 'B', 'N', 'M', '.', '_']
                  .map((k) => _buildKey(k)),
              GestureDetector(
                onTap: onBackspace,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  width: 60,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.backspace,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _buildKey(' ', width: 400, isSpace: true),
        ],
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildKey(String label, {double width = 45, bool isSpace = false}) {
    return GestureDetector(
      onTap: () => onKeyTap(isSpace ? " " : label),
      child: Container(
        margin: const EdgeInsets.all(4),
        width: width,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: isSpace
              ? const Text(
                  "SPACE",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
