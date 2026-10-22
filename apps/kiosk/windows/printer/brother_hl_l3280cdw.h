#ifndef SKP_PRINTER_BROTHER_HL_L3280CDW_H_
#define SKP_PRINTER_BROTHER_HL_L3280CDW_H_

#include <optional>
#include <string>
#include <vector>

#include "snmp_v2c_client.h"

namespace skp_printer {

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

struct BrotherSnmpSnapshot {
  bool snmp_ok = false;
  std::optional<int64_t> page_counter;
  std::vector<BrotherSupplyReading> supplies;
  std::vector<BrotherTrayReading> trays;
  std::string snmp_state;  // may refine spooler state (jam/paper_out/…)
  std::string last_error_code;
};

class BrotherHlL3280CdwProfile {
 public:
  BrotherHlL3280CdwProfile(std::string host, std::string community);

  BrotherSnmpSnapshot Read() const;
  std::optional<int64_t> ReadPageCounter() const;

  static constexpr const char* kModelName = "Brother HL-L3280CDW";

 private:
  SnmpV2cClient client_;
};

}  // namespace skp_printer

#endif  // SKP_PRINTER_BROTHER_HL_L3280CDW_H_
