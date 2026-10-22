#ifndef SKP_PRINTER_BROTHER_HL_L3280CDW_H_
#define SKP_PRINTER_BROTHER_HL_L3280CDW_H_

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

#include "snmp_v2c_client.h"

namespace skp_printer {

struct BrotherOids {
  static constexpr const char* kHrPrinterStatus = "1.3.6.1.2.1.25.3.5.1.1.1";
  static constexpr const char* kHrPrinterDetectedErrorState =
      "1.3.6.1.2.1.25.3.5.1.2.1";
  static constexpr const char* kPrtMarkerLifeCount = "1.3.6.1.2.1.43.10.2.1.4.1.1";
  static constexpr const char* kSupplyLevelFmt = "1.3.6.1.2.1.43.11.1.1.9.1.";
  static constexpr const char* kSupplyMaxFmt = "1.3.6.1.2.1.43.11.1.1.8.1.";
  static constexpr const char* kSupplyDescFmt = "1.3.6.1.2.1.43.11.1.1.6.1.";
  static constexpr const char* kTrayNameOid = "1.3.6.1.2.1.43.8.2.1.13.1.1";
  static constexpr const char* kTrayLevelOid = "1.3.6.1.2.1.43.8.2.1.10.1.1";
  static constexpr const char* kTrayMaxOid = "1.3.6.1.2.1.43.8.2.1.9.1.1";
};

struct BrotherSupplyReading {
  std::string name;
  std::string color;
  std::optional<int> level_percent;
  std::string status;
};

struct BrotherTrayReading {
  std::string name;
  std::optional<int> level_percent;
  std::string status;
};

struct BrotherErrorFlagsDecoded {
  bool no_paper = false;     // 0x40 — lab-confirmed
  bool jammed = false;       // 0x04 — RFC
  bool offline_bit = false;  // 0x02 — NOT proof of unreachable
  bool low_paper = false;
  bool low_toner = false;
  bool no_toner = false;
  bool door_open = false;
};

struct BrotherSnmpSnapshot {
  bool snmp_ok = false;
  std::optional<int64_t> page_counter;
  std::optional<int> hr_printer_status;
  std::string hr_printer_status_label;
  std::string error_flags_hex;
  BrotherErrorFlagsDecoded error_flags;
  std::vector<BrotherSupplyReading> supplies;
  std::vector<BrotherTrayReading> trays;
  std::string snmp_state;
  std::string last_error_code;
  std::string poll_error;
};

class BrotherHlL3280CdwProfile {
 public:
  BrotherHlL3280CdwProfile(std::string host, std::string community, int timeout_ms = 3000);

  BrotherSnmpSnapshot Read() const;
  std::optional<int64_t> ReadPageCounter() const;

  static constexpr const char* kModelName = "Brother HL-L3280CDW";

  static std::string StatusLabel(int hr_status);
  static BrotherErrorFlagsDecoded DecodeErrorFlags(const std::string& raw_octets);
  static std::string OctetsToHex(const std::string& raw_octets);

 private:
  SnmpV2cClient client_;
};

}  // namespace skp_printer

#endif  // SKP_PRINTER_BROTHER_HL_L3280CDW_H_
