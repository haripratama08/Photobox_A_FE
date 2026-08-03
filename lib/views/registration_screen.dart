import 'package:flutter/material.dart';
import 'package:photobox_pro/widgets/app_close_button.dart';
import 'frame_selection_screen.dart';
import '../widgets/custom_keyboard.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController waCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();

  TextEditingController? activeController;

  void _submitData() {
    if (nameCtrl.text.isEmpty ||
        (waCtrl.text.isEmpty && emailCtrl.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text("Harap isi Nama dan pilih salah satu (WhatsApp/Email)!"),
            ],
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(20),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FrameSelectionScreen(
          userName: nameCtrl.text,
          userWA: waCtrl.text,
          userEmail: emailCtrl.text,
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    waCtrl.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar dibuat transparan hanya untuk tombol back
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [AppCloseButton()],
      ),
      extendBodyBehindAppBar: true, // Agar background memenuhi layar
      body: GestureDetector(
        onTap: () {
          if (activeController != null) {
            setState(() => activeController = null);
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Container(
          // Tambahkan subtle background gradient jika ingin tidak terlalu hitam pekat
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF1E1E1E), Color(0xFF0F0F0F)],
              center: Alignment.center,
              radius: 1.5,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 550),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: const Color(
                            0xFF1A1A1A), // Warna card sedikit lebih terang dari background
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Form
                          const Text(
                            "Data Pengiriman",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Soft file foto akan dikirimkan ke kontak di bawah ini.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Form Fields
                          _buildTextField(
                            controller: nameCtrl,
                            label: "Nama Lengkap (Wajib)",
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: waCtrl,
                            label: "Nomor WhatsApp",
                            icon: Icons.phone_android_rounded,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: emailCtrl,
                            label: "Alamat Email",
                            icon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 40),

                          // Action Button
                          Container(
                            height: 65,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xff0000cd).withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff0000cd),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation:
                                    0, // Elevation dihandle oleh Container BoxShadow
                              ),
                              onPressed: _submitData,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "LANJUT PILIH FRAME",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Custom Keyboard Layer
              if (activeController != null)
                CustomKeyboard(
                  onKeyTap: (val) {
                    setState(() {
                      activeController!.text += val;
                    });
                  },
                  onBackspace: () {
                    if (activeController!.text.isNotEmpty) {
                      setState(() {
                        activeController!.text =
                            activeController!.text.substring(
                          0,
                          activeController!.text.length - 1,
                        );
                      });
                    }
                  },
                  onClose: () {
                    setState(() {
                      activeController = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget custom TextField yang jauh lebih estetik
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => setState(() => activeController = controller),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.06), // Efek kaca gelap
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 16,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: 24,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none, // Tanpa border saat tidak aktif
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xff0000cd), // Highlight biru saat disentuh
            width: 2,
          ),
        ),
      ),
    );
  }
}
