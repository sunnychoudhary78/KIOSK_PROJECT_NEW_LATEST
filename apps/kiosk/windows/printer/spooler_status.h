#ifndef SKP_PRINTER_SPOOLER_STATUS_H_
#define SKP_PRINTER_SPOOLER_STATUS_H_

#include <string>

namespace skp_printer {

struct SpoolerPrinterInfo {
  bool found = false;
  bool online = false;
  std::string name;
  std::string state;  // ready|printing|jam|paper_out|toner_low|offline|error|unknown
  std::string last_error_code;
};

// Resolve by preferred substring (case-insensitive). Empty preferred uses default.
SpoolerPrinterInfo QuerySpoolerStatus(const std::string& preferred_name_substring);

}  // namespace skp_printer

#endif  // SKP_PRINTER_SPOOLER_STATUS_H_
