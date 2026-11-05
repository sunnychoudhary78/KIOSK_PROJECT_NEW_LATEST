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

struct SpoolerJobLookup {
  bool found = false;
  uint32_t job_id = 0;
  int win32_error = 0;
};

struct SpoolerCancelResult {
  bool ok = false;
  bool purged = false;
  uint32_t job_id = 0;
  int win32_error = 0;
};

// USB-port queue only. Name match is case-insensitive inside that set.
// Network ports (WSD, IP_, TCP) are never selected.
UsbPrinterResolution ResolveUsbPrinter(const std::string& preferred_name_substring);

// Same USB queue as ResolveUsbPrinter, plus live Win32 status and jobs.
SpoolerPrinterInfo QuerySpoolerStatus(const std::string& preferred_name_substring);

// Match JOB_INFO_1W.pDocument to document_title (case-insensitive, trimmed).
SpoolerJobLookup FindUsbSpoolerJobByDocument(const std::string& preferred_name_substring,
                                             const std::string& document_title);

// Cancel job_id via SetJob(JOB_CONTROL_DELETE/CANCEL), else SetPrinter(PRINTER_CONTROL_PURGE).
// job_id == 0 means purge the whole USB queue.
SpoolerCancelResult CancelUsbSpoolerJobs(const std::string& preferred_name_substring,
                                         uint32_t job_id);

}  // namespace skp_printer

#endif  // SKP_PRINTER_SPOOLER_STATUS_H_
