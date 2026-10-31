#include "spooler_status.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <winspool.h>

#include <algorithm>
#include <cctype>
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

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return {};
  }
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  if (size <= 0) {
    return {};
  }
  std::wstring out(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), out.data(), size);
  return out;
}

std::string ToLower(std::string s) {
  std::transform(s.begin(), s.end(), s.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return s;
}

std::string Trim(std::string s) {
  auto is_space = [](unsigned char c) { return std::isspace(c) != 0; };
  s.erase(s.begin(), std::find_if(s.begin(), s.end(), [&](char c) { return !is_space(static_cast<unsigned char>(c)); }));
  s.erase(std::find_if(s.rbegin(), s.rend(), [&](char c) { return !is_space(static_cast<unsigned char>(c)); }).base(),
          s.end());
  return s;
}

bool IsUsbPort(const std::string& port) {
  const std::string lower = ToLower(Trim(port));
  return lower.size() >= 3 && lower.compare(0, 3, "usb") == 0;
}

struct ListedPrinter {
  std::wstring name_wide;
  std::string name;
  std::string port;
  bool is_default = false;
  DWORD status = 0;
};

struct EnumOutcome {
  bool failed = false;
  std::vector<ListedPrinter> printers;
};

EnumOutcome EnumerateInstalledPrinters() {
  EnumOutcome outcome;
  DWORD needed = 0;
  DWORD returned = 0;
  EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 2, nullptr, 0, &needed,
                &returned);
  if (needed == 0) {
    return outcome;
  }
  std::vector<BYTE> buffer(needed);
  if (!EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 2, buffer.data(),
                     needed, &needed, &returned)) {
    outcome.failed = true;
    return outcome;
  }

  auto* printers = reinterpret_cast<PRINTER_INFO_2W*>(buffer.data());
  outcome.printers.reserve(returned);
  for (DWORD i = 0; i < returned; ++i) {
    auto& p = printers[i];
    ListedPrinter listed;
    listed.name = WideToUtf8(p.pPrinterName);
    listed.name_wide = p.pPrinterName ? std::wstring(p.pPrinterName) : Utf8ToWide(listed.name);
    listed.port = WideToUtf8(p.pPortName);
    listed.is_default = (p.Attributes & PRINTER_ATTRIBUTE_DEFAULT) != 0;
    listed.status = p.Status;
    outcome.printers.push_back(std::move(listed));
  }
  return outcome;
}

const ListedPrinter* SelectUsbPrinter(const std::vector<ListedPrinter>& printers,
                                      const std::string& preferred_name_substring) {
  std::vector<const ListedPrinter*> usb;
  usb.reserve(printers.size());
  for (const auto& printer : printers) {
    if (IsUsbPort(printer.port)) {
      usb.push_back(&printer);
    }
  }
  if (usb.empty()) {
    return nullptr;
  }

  const std::string needle = ToLower(Trim(preferred_name_substring));
  if (!needle.empty()) {
    std::vector<const ListedPrinter*> matches;
    for (const auto* printer : usb) {
      if (ToLower(printer->name).find(needle) != std::string::npos) {
        matches.push_back(printer);
      }
    }
    if (matches.empty()) {
      return nullptr;
    }
    for (const auto* printer : matches) {
      if (ToLower(printer->name) == needle) {
        return printer;
      }
    }
    for (const auto* printer : matches) {
      if (printer->is_default) {
        return printer;
      }
    }
    return matches.front();
  }

  for (const auto* printer : usb) {
    if (printer->is_default) {
      return printer;
    }
  }
  if (usb.size() == 1) {
    return usb.front();
  }
  return nullptr;
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

void ReadJobs(HANDLE handle, SpoolerPrinterInfo* info) {
  DWORD jobs_needed = 0;
  DWORD jobs_returned = 0;
  EnumJobsW(handle, 0, 0xFFFFFFFF, 1, nullptr, 0, &jobs_needed, &jobs_returned);
  if (jobs_needed == 0) {
    return;
  }
  std::vector<BYTE> jobs_buf(jobs_needed);
  if (!EnumJobsW(handle, 0, 0xFFFFFFFF, 1, jobs_buf.data(), jobs_needed, &jobs_needed,
                 &jobs_returned)) {
    return;
  }
  auto* jobs = reinterpret_cast<JOB_INFO_1W*>(jobs_buf.data());
  for (DWORD i = 0; i < jobs_returned; ++i) {
    const DWORD st = jobs[i].Status;
    if (st & (JOB_STATUS_PRINTING | JOB_STATUS_SPOOLING)) {
      info->jobs_printing += 1;
    } else {
      info->jobs_queued += 1;
    }
    if (i + 1 == jobs_returned || info->latest_job_id == 0) {
      info->latest_job_id = jobs[i].JobId;
      if (st & JOB_STATUS_ERROR) {
        info->latest_job_status = "error";
      } else if (st & JOB_STATUS_PAUSED) {
        info->latest_job_status = "paused";
      } else if (st & JOB_STATUS_PRINTING) {
        info->latest_job_status = "printing";
      } else if (st & JOB_STATUS_SPOOLING) {
        info->latest_job_status = "spooling";
      } else if (st & JOB_STATUS_PRINTED) {
        info->latest_job_status = "printed";
      } else {
        info->latest_job_status = "queued";
      }
    }
  }
}

}  // namespace

UsbPrinterResolution ResolveUsbPrinter(const std::string& preferred_name_substring) {
  UsbPrinterResolution resolution;
  const EnumOutcome listed = EnumerateInstalledPrinters();
  if (listed.failed) {
    return resolution;
  }
  const ListedPrinter* chosen = SelectUsbPrinter(listed.printers, preferred_name_substring);
  if (chosen == nullptr) {
    return resolution;
  }
  resolution.found = true;
  resolution.name = chosen->name;
  resolution.port = chosen->port;
  return resolution;
}

SpoolerPrinterInfo QuerySpoolerStatus(const std::string& preferred_name_substring) {
  SpoolerPrinterInfo info;
  const EnumOutcome listed = EnumerateInstalledPrinters();
  if (listed.failed) {
    info.state = "unknown";
    info.last_error_code = "ENUM_FAILED";
    return info;
  }

  const ListedPrinter* chosen = SelectUsbPrinter(listed.printers, preferred_name_substring);
  if (chosen == nullptr) {
    info.state = "offline";
    info.last_error_code = "USB_PRINTER_NOT_FOUND";
    return info;
  }

  info.found = true;
  info.name = chosen->name;
  info.port = chosen->port;
  MapStatus(chosen->status, &info);

  HANDLE handle = nullptr;
  if (!chosen->name_wide.empty() &&
      OpenPrinterW(const_cast<LPWSTR>(chosen->name_wide.c_str()), &handle, nullptr)) {
    DWORD bytes = 0;
    GetPrinterW(handle, 2, nullptr, 0, &bytes);
    if (bytes > 0) {
      std::vector<BYTE> detail(bytes);
      if (GetPrinterW(handle, 2, detail.data(), bytes, &bytes)) {
        auto* live = reinterpret_cast<PRINTER_INFO_2W*>(detail.data());
        MapStatus(live->Status, &info);
        info.port = WideToUtf8(live->pPortName);
        if (info.port.empty()) {
          info.port = chosen->port;
        }
      }
    }
    ReadJobs(handle, &info);
    ClosePrinter(handle);
  }
  return info;
}

}  // namespace skp_printer
