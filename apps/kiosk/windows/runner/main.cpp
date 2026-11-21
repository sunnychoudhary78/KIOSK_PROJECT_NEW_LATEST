#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {
constexpr wchar_t kSingleInstanceMutexName[] = L"Local\\skp-kiosk";
constexpr wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr wchar_t kWindowTitle[] = L"ATHENA";

// Held for process lifetime so a second launch sees ERROR_ALREADY_EXISTS.
HANDLE g_single_instance_mutex = nullptr;

bool ClaimSingleInstanceOrFocusExisting() {
  g_single_instance_mutex =
      ::CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  if (g_single_instance_mutex == nullptr) {
    return true;  // Fail open: allow start if mutex creation fails.
  }
  if (::GetLastError() != ERROR_ALREADY_EXISTS) {
    return true;
  }
  HWND existing = ::FindWindowW(kWindowClassName, kWindowTitle);
  if (existing != nullptr) {
    if (::IsIconic(existing)) {
      ::ShowWindow(existing, SW_RESTORE);
    }
    ::SetForegroundWindow(existing);
  }
  ::CloseHandle(g_single_instance_mutex);
  g_single_instance_mutex = nullptr;
  return false;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (!ClaimSingleInstanceOrFocusExisting()) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  // Laptop-friendly default; UI is responsive up to the 1448×1086 (4:3) kiosk panel.
  Win32Window::Size size(1280, 800);
  if (!window.Create(kWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
