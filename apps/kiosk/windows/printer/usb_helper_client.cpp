#include "usb_helper_client.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <mutex>
#include <string>

namespace skp_printer {
namespace {

std::wstring HelperPath() {
  wchar_t module[MAX_PATH];
  DWORD length = GetModuleFileNameW(nullptr, module, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return {};
  }
  std::wstring path(module, length);
  const auto slash = path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return {};
  }
  path.resize(slash + 1);
  path += L"skp_printer_usb.exe";
  return path;
}

bool HelperExists(const std::wstring& path) {
  if (path.empty()) return false;
  const DWORD attrs = GetFileAttributesW(path.c_str());
  return attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

void StartHelper(const std::wstring& path) {
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION process{};
  std::wstring command = L"\"" + path + L"\"";
  if (!CreateProcessW(path.c_str(), command.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW,
                      nullptr, nullptr, &startup, &process)) {
    return;
  }
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
}

HANDLE OpenPipe(DWORD timeout_ms) {
  const wchar_t* name = L"\\\\.\\pipe\\skp-brother-usb";
  const ULONGLONG deadline = GetTickCount64() + timeout_ms;
  for (;;) {
    HANDLE pipe = CreateFileW(name, GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING,
                              FILE_FLAG_OVERLAPPED, nullptr);
    if (pipe != INVALID_HANDLE_VALUE) {
      return pipe;
    }
    if (GetTickCount64() >= deadline) {
      return INVALID_HANDLE_VALUE;
    }
    WaitNamedPipeW(name, 200);
  }
}

bool WriteAll(HANDLE pipe, OVERLAPPED* overlapped, const std::string& bytes, DWORD timeout_ms) {
  ResetEvent(overlapped->hEvent);
  DWORD written = 0;
  BOOL ok = WriteFile(pipe, bytes.data(), static_cast<DWORD>(bytes.size()), &written, overlapped);
  if (!ok && GetLastError() != ERROR_IO_PENDING) {
    return false;
  }
  if (!ok && WaitForSingleObject(overlapped->hEvent, timeout_ms) != WAIT_OBJECT_0) {
    CancelIo(pipe);
    return false;
  }
  if (!GetOverlappedResult(pipe, overlapped, &written, FALSE)) {
    return false;
  }
  return written == bytes.size();
}

bool ReadLine(HANDLE pipe, OVERLAPPED* overlapped, std::string* line, DWORD timeout_ms) {
  const ULONGLONG deadline = GetTickCount64() + timeout_ms;
  std::string acc;
  char buffer[512];
  while (acc.find('\n') == std::string::npos) {
    const ULONGLONG now = GetTickCount64();
    if (now >= deadline) {
      CancelIo(pipe);
      return false;
    }
    ResetEvent(overlapped->hEvent);
    DWORD read = 0;
    BOOL ok = ReadFile(pipe, buffer, sizeof(buffer), &read, overlapped);
    if (!ok && GetLastError() != ERROR_IO_PENDING) {
      return false;
    }
    if (!ok && WaitForSingleObject(overlapped->hEvent, static_cast<DWORD>(deadline - now)) !=
                   WAIT_OBJECT_0) {
      CancelIo(pipe);
      return false;
    }
    if (!GetOverlappedResult(pipe, overlapped, &read, FALSE)) {
      return false;
    }
    if (read == 0) {
      return false;
    }
    acc.append(buffer, buffer + read);
    if (acc.size() > 256 * 1024) {
      return false;
    }
  }
  const auto end = acc.find('\n');
  *line = acc.substr(0, end);
  if (!line->empty() && line->back() == '\r') {
    line->pop_back();
  }
  return !line->empty();
}

std::string Transact(const std::string& scope) {
  const std::wstring helper = HelperPath();
  if (!HelperExists(helper)) {
    return "{\"ok\":false,\"connected\":false,\"error\":\"helper_missing\"}";
  }
  HANDLE pipe = OpenPipe(300);
  if (pipe == INVALID_HANDLE_VALUE) {
    StartHelper(helper);
    pipe = OpenPipe(8000);
  }
  if (pipe == INVALID_HANDLE_VALUE) {
    return "{\"ok\":false,\"connected\":false,\"error\":\"helper_missing\"}";
  }

  OVERLAPPED overlapped{};
  overlapped.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  std::string response;
  const std::string request = std::string("{\"scope\":\"") + scope + "\"}\n";
  // First open of the printer can take the SDK's 15 second timeout.
  const bool wrote = overlapped.hEvent != nullptr &&
                     WriteAll(pipe, &overlapped, request, 5000);
  const bool read = wrote && ReadLine(pipe, &overlapped, &response, 25000);
  if (overlapped.hEvent != nullptr) {
    CloseHandle(overlapped.hEvent);
  }
  CloseHandle(pipe);
  if (!read) {
    return "{\"ok\":false,\"connected\":false,\"error\":\"usb_timeout\"}";
  }
  return response;
}

std::mutex& BusyMutex() {
  static std::mutex mutex;
  return mutex;
}

}  // namespace

std::string RequestUsbSnapshot(const std::string& scope) {
  std::unique_lock<std::mutex> lock(BusyMutex(), std::try_to_lock);
  if (!lock.owns_lock()) {
    return "{\"ok\":false,\"connected\":false,\"error\":\"busy\"}";
  }
  const std::string normalized = scope == "full" ? "full" : "fast";
  return Transact(normalized);
}

}  // namespace skp_printer
