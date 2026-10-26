#ifndef SKP_PRINTER_SNMP_BER_H_
#define SKP_PRINTER_SNMP_BER_H_

#include <cstdint>
#include <optional>
#include <string>

namespace skp_printer {

inline bool IsSnmpIntegerTag(uint8_t tag) {
  return tag == 0x02 || tag == 0x41 || tag == 0x42 || tag == 0x43;
}

// INTEGER (0x02) is signed. Counter32 (0x41), Gauge32 (0x42), and TimeTicks
// (0x43) are unsigned so a high bit does not become a negative page count.
inline std::optional<int64_t> DecodeSnmpInteger(uint8_t tag, const uint8_t* bytes, size_t len) {
  if (!IsSnmpIntegerTag(tag) || bytes == nullptr || len == 0 || len > 8) {
    return std::nullopt;
  }
  if (tag == 0x02) {
    int64_t value = static_cast<int8_t>(bytes[0]);
    for (size_t i = 1; i < len; ++i) {
      value = (value << 8) | bytes[i];
    }
    return value;
  }
  uint64_t value = 0;
  for (size_t i = 0; i < len; ++i) {
    value = (value << 8) | bytes[i];
  }
  return static_cast<int64_t>(value);
}

// A zero-length OCTET STRING is a successful empty value. Do not index the
// buffer for it: the read cursor is already one past the last byte.
inline std::optional<std::string> CopySnmpOctetBytes(const uint8_t* bytes, size_t len) {
  if (len == 0) {
    return std::string();
  }
  if (bytes == nullptr) {
    return std::nullopt;
  }
  return std::string(reinterpret_cast<const char*>(bytes), len);
}

}  // namespace skp_printer

#endif  // SKP_PRINTER_SNMP_BER_H_
