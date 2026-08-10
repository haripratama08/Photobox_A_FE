#include "my_application.h"

#include <X11/Xlib.h>
#include <glib.h>

namespace {

bool IsFalse(const gchar* value) {
  return value != nullptr &&
         (g_ascii_strcasecmp(value, "false") == 0 ||
          g_ascii_strcasecmp(value, "0") == 0 ||
          g_ascii_strcasecmp(value, "no") == 0);
}

void ConfigureGraphicsFallback() {
  // Some X11 remote-desktop/Intel-Mesa combinations fail while Flutter creates
  // its GLX context (BadAccess, request 152/minor 26). Force Mesa's software
  // renderer before GTK opens the display. This keeps pointer/touch events on
  // XInput while avoiding the unstable hardware GLX context.
  //
  // Set PHOTOBOX_USE_SOFTWARE_RENDERING=false to opt out on a machine whose
  // hardware renderer is known to be stable.
  if (!IsFalse(g_getenv("PHOTOBOX_USE_SOFTWARE_RENDERING"))) {
    g_setenv("LIBGL_ALWAYS_SOFTWARE", "1", FALSE);
    g_setenv("GALLIUM_DRIVER", "llvmpipe", FALSE);
    g_message("Photobox graphics fallback enabled (Mesa llvmpipe)");
  }
}

}  // namespace

int main(int argc, char** argv) {
  ConfigureGraphicsFallback();

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
