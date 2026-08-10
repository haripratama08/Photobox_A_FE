#include "my_application.h"

#include <X11/Xlib.h>

int main(int argc, char** argv) {
  // Flutter merender pada thread terpisah. Xlib harus diinisialisasi untuk
  // penggunaan multi-thread sebelum GTK/GDK membuka koneksi display; tanpa
  // ini GLX dapat berhenti dengan BadAccess (minor code 26), terutama pada
  // sesi remote desktop seperti AnyDesk.
  if (XInitThreads() == 0) {
    g_warning("Failed to initialize X11 thread support");
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
