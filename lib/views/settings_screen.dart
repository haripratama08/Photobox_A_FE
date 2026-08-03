import 'package:flutter/material.dart';
import 'package:photobox_pro/services/socket_services.dart';
import 'package:photobox_pro/services/storage_services.dart';
import 'package:photobox_pro/viewmodels/setting_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:photobox_pro/widgets/app_close_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SettingsViewModel(
        context.read<SocketService>(),
        context.read<StorageService>(),
      ),
      child: Consumer<SettingsViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Pengaturan Kamera"),
              backgroundColor: const Color(0xFF1A1A1A),
              actions: const [AppCloseButton()],
            ),
            body: vm.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xff0000cd)))
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      SwitchListTile(
                        title: const Text("Mirror Live View"),
                        subtitle: const Text("Balikkan kamera seperti cermin"),
                        activeColor: const Color(0xff0000cd),
                        value: vm.isMirror,
                        onChanged: vm.setMirror,
                      ),
                      const Divider(height: 40),
                      ListTile(
                        title: const Text("ISO"),
                        trailing: DropdownButton<String>(
                          value: vm.selectedIso,
                          dropdownColor: Colors.grey[900],
                          items: ['Auto', '100', '200', '400', '800', '1600']
                              .map((String val) => DropdownMenuItem(
                                  value: val, child: Text(val)))
                              .toList(),
                          onChanged: (val) => vm.setIso(val!),
                        ),
                      ),
                      ListTile(
                        title: const Text("Aperture"),
                        trailing: DropdownButton<String>(
                          value: vm.selectedAperture,
                          dropdownColor: Colors.grey[900],
                          items: ['f/1.8', 'f/2.8', 'f/3.5', 'f/4.0', 'f/5.6']
                              .map((String val) => DropdownMenuItem(
                                  value: val, child: Text(val)))
                              .toList(),
                          onChanged: (val) => vm.setAperture(val!),
                        ),
                      ),
                      const Divider(height: 40),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          "SIMPAN PENGATURAN",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: const Color(0xff0000cd),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await vm.saveSettings();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "✅ Pengaturan berhasil disimpan & diterapkan!"),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text("Trigger Fokus Otomatis"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          vm.triggerAutoFocus();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Meminta lensa untuk fokus...")),
                          );
                        },
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
