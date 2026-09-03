#include "flutter_window.h"

#include <optional>
#include <string>

#include <windows.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

/// True, wenn die App mit `--background` gestartet wurde (Autostart).
///
/// Bewusst über die rohe Befehlszeile und nicht über die Dart-Argumente:
/// Die Entscheidung, ob das Fenster überhaupt erscheint, fällt im nativen
/// Startup-Pfad, lange bevor Dart läuft.
bool IsBackgroundLaunch() {
  const wchar_t* line = ::GetCommandLineW();
  if (line == nullptr) {
    return false;
  }
  return std::wstring(line).find(L"--background") != std::wstring::npos;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // Autostart-Modus: Wird die App mit `--background` gestartet (siehe
    // lib/core/services/autostart_service.dart), bleibt das Fenster zu. Der
    // Prozess läuft weiter und bedient den Zeitplan — genau das, was ein
    // Hintergrund-Dienst tun soll. Ohne den Schalter verhält sich alles wie
    // bisher.
    if (!IsBackgroundLaunch()) {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
