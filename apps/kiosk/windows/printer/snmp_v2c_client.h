#ifndef SKP_PRINTER_SNMP_V2C_CLIENT_H_
#define SKP_PRINTER_SNMP_V2C_CLIENT_H_

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace skp_printer {

struct SnmpOid {
  std::vector<uint32_t> arcs;

  static std::optional<SnmpOid> Parse(const std::string& dotted);
};

class SnmpV2cClient {
 public:
  SnmpV2cClient(std::string host, std::string community, int timeout_ms = 2000);

  std::optional<int64_t> GetInteger(const SnmpOid& oid) const;
  std::optional<std::string> GetOctetString(const SnmpOid& oid) const;

 private:
  std::optional<std::vector<uint8_t>> Transact(const std::vector<uint8_t>& request) const;
  std::vector<uint8_t> BuildGetRequest(const SnmpOid& oid, int32_t request_id) const;

  std::string host_;
  std::string community_;
  int timeout_ms_;
};

}  // namespace skp_printer

#endif  // SKP_PRINTER_SNMP_V2C_CLIENT_H_
