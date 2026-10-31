#ifndef SKP_PRINTER_SPOOLER_STATUS_H_
#define SKP_PRINTER_SPOOLER_STATUS_H_

#include <cstdint>
#include <string>

namespace skp_printer {

struct UsbPrinterResolution {
  bool found = false;
  std::string name;
  std::string port;
};

struct SpoolerPrinterInfo {
  bool found = false;
  bool online = false;
  std::string name;
  std::string port;
  std::string state;  // ready|printing|jam|paper_out|toner_low|offline|error|unknown
  std::string last_error_code;
  int jobs_queued = 0;
  int jobs_printing = 0;
  uint32_t latest_job_id = 0;
  std::string latest_job_status;
};

// USB-port queue only. Name match is case-insensitive inside that set.
// Network ports (WSD, IP_, TCP) are never selected.
UsbPrinterResolution ResolveUsbPrinter(const std::string& preferred_name_substring);

// Same USB queue as ResolveUsbPrinter, plus live Win32 status and jobs.
SpoolerPrinterInfo QuerySpoolerStatus(const std::string& preferred_name_substring);

}  // namespace skp_printer

#endif  // SKP_PRINTER_SPOOLER_STATUS_H_
