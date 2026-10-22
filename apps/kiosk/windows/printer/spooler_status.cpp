#include "spooler_status.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <winspool.h>

#include <algorithm>
#include <vector>

#pragma comment(lib, "winspool.lib")

namespace skp_printer {
namespace {

std::string WideToUtf8(const wchar_t* wide) {
  if (!wide) {
    return {};
  }
  int size = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) {
    return {};
  }
  std::string out(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, out.data(), size, nullptr, nullptr);
  return out;
}

std::string ToLower(std::string s) {
  std::transform(s.begin(), s.end(), s.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return s;
}

void MapStatus(DWORD status, SpoolerPrinterInfo* info) {
  info->online = (status & (PRINTER_STATUS_OFFLINE | PRINTER_STATUS_NOT_AVAILABLE)) == 0;
  if (status & (PRINTER_STATUS_PAPER_JAM | PRINTER_STATUS_ERROR)) {
    if (status & PRINTER_STATUS_PAPER_JAM) {
      info->state = "jam";
      info->last_error_code = "PAPER_JAM";
      return;
    }
  }
  if (status & (PRINTER_STATUS_PAPER_OUT | PRINTER_STATUS_NO_TONER)) {
    if (status & PRINTER_STATUS_PAPER_OUT) {
      info->state = "paper_out";
      info->last_error_code = "PAPER_OUT";
      return;
    }
    if (status & PRINTER_STATUS_NO_TONER) {
      info->state = "toner_low";
      info->last_error_code = "NO_TONER";
      return;
    }
  }
  if (status & (PRINTER_STATUS_OFFLINE | PRINTER_STATUS_NOT_AVAILABLE)) {
    info->state = "offline";
    info->last_error_code = "OFFLINE";
    return;
  }
  if (status & (PRINTER_STATUS_PRINTING | PRINTER_STATUS_PROCESSING | PRINTER_STATUS_BUSY)) {
    info->state = "printing";
    return;
  }
  if (status & (PRINTER_STATUS_TONER_LOW | PRINTER_STATUS_DOOR_OPEN | PRINTER_STATUS_USER_INTERVENTION |
                PRINTER_STATUS_ERROR)) {
    if (status & PRINTER_STATUS_TONER_LOW) {
      info->state = "toner_low";
      info->last_error_code = "TONER_LOW";
      return;
    }
    info->state = "error";
    info->last_error_code = "PRINTER_ERROR";
    return;
  }
  info->state = "ready";
}

}  // namespace

SpoolerPrinterInfo QuerySpoolerStatus(const std::string& preferred_name_substring) {
  SpoolerPrinterInfo info;
  DWORD needed = 0;
  DWORD returned = 0;
  EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 2, nullptr, 0, &needed,
                &returned);
  if (needed == 0) {
    info.state = "offline";
    info.last_error_code = "NO_PRINTERS";
    return info;
  }
  std::vector<BYTE> buffer(needed);
  if (!EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 2, buffer.data(),
                     needed, &needed, &returned)) {
    info.state = "unknown";
    info.last_error_code = "ENUM_FAILED";
    return info;
  }

  auto* printers = reinterpret_cast<PRINTER_INFO_2W*>(buffer.data());
  const std::string needle = ToLower(preferred_name_substring);
  PRINTER_INFO_2W* chosen = nullptr;
  PRINTER_INFO_2W* default_printer = nullptr;

  for (DWORD i = 0; i < returned; ++i) {
    auto& p = printers[i];
    std::string name = WideToUtf8(p.pPrinterName);
    if (p.Attributes & PRINTER_ATTRIBUTE_DEFAULT) {
      default_printer = &p;
    }
    if (!needle.empty() && ToLower(name).find(needle) != std::string::npos) {
      chosen = &p;
      break;
    }
  }
  if (!chosen) {
    chosen = default_printer;
  }
  if (!chosen && returned == 1) {
    chosen = &printers[0];
  }
  if (!chosen) {
    info.state = "unknown";
    info.last_error_code = "PRINTER_NOT_RESOLVED";
    return info;
  }

  info.found = true;
  info.name = WideToUtf8(chosen->pPrinterName);
  MapStatus(chosen->Status, &info);

  HANDLE handle = nullptr;
  if (OpenPrinterW(chosen->pPrinterName, &handle, nullptr)) {
    DWORD bytes = 0;
    GetPrinterW(handle, 2, nullptr, 0, &bytes);
    if (bytes > 0) {
      std::vector<BYTE> detail(bytes);
      if (GetPrinterW(handle, 2, detail.data(), bytes, &bytes)) {
        auto* live = reinterpret_cast<PRINTER_INFO_2W*>(detail.data());
        MapStatus(live->Status, &info);
      }
    }
    ClosePrinter(handle);
  }
  return info;
}

}  // namespace skp_printer
