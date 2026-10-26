#ifndef SKP_PRINTER_BROTHER_MAINTENANCE_H_
#define SKP_PRINTER_BROTHER_MAINTENANCE_H_

#include <cstddef>
#include <cstdint>
#include <optional>
#include <vector>

namespace skp_printer {

// Brother private maintenance blobs are not SNMP integers. Each record is
// tag, 0x01, 0x04, then four big-endian value bytes. 0xFF 0xFF 0xFF is
// padding. 0xFF 0xFF 0xFF 0xFF ends the blob. This matches the lab decoder
// in scripts/test_brother_snmp.ps1.

struct BrotherMaintenanceRecord {
  uint8_t tag = 0;
  std::optional<uint32_t> value;
};

struct BrotherMaintenance {
  bool available = false;
  std::optional<int> black_toner_percent;
  std::optional<int> cyan_toner_percent;
  std::optional<int> magenta_toner_percent;
  std::optional<int> yellow_toner_percent;
  std::optional<int64_t> pages_total;
  std::optional<int64_t> pages_color;
  std::optional<int64_t> pages_black_white;
  std::optional<int64_t> belt_remaining_pages;
  std::optional<int64_t> fuser_remaining_pages;
};

inline std::vector<BrotherMaintenanceRecord> DecodeBrotherMaintenanceRecords(
    const uint8_t* data, size_t len) {
  std::vector<BrotherMaintenanceRecord> records;
  if (data == nullptr) {
    return records;
  }
  size_t i = 0;
  while (i < len) {
    if (i + 4 <= len && data[i] == 0xFF && data[i + 1] == 0xFF && data[i + 2] == 0xFF &&
        data[i + 3] == 0xFF) {
      break;
    }
    if (i + 3 <= len && data[i] == 0xFF && data[i + 1] == 0xFF && data[i + 2] == 0xFF) {
      i += 3;
      continue;
    }
    if (data[i] == 0xFF && i + 1 == len) {
      break;
    }
    if (i + 3 > len || data[i + 1] != 0x01 || data[i + 2] != 0x04) {
      BrotherMaintenanceRecord bad;
      bad.tag = data[i];
      records.push_back(bad);
      break;
    }

    const uint8_t tag = data[i];
    i += 3;
    uint8_t value_bytes[4];
    size_t count = 0;
    while (count < 4 && i < len) {
      if (i + 3 <= len && data[i] == 0xFF && data[i + 1] == 0xFF && data[i + 2] == 0xFF) {
        i += 3;
        continue;
      }
      value_bytes[count++] = data[i++];
    }

    BrotherMaintenanceRecord record;
    record.tag = tag;
    if (count != 4) {
      records.push_back(record);
      break;
    }
    record.value = (static_cast<uint32_t>(value_bytes[0]) << 24) |
                   (static_cast<uint32_t>(value_bytes[1]) << 16) |
                   (static_cast<uint32_t>(value_bytes[2]) << 8) |
                   static_cast<uint32_t>(value_bytes[3]);
    records.push_back(record);
  }
  return records;
}

inline std::optional<uint32_t> FindBrotherMaintenanceTag(
    const std::vector<BrotherMaintenanceRecord>& records, uint8_t tag) {
  for (const auto& record : records) {
    if (record.tag == tag && record.value) {
      return record.value;
    }
  }
  return std::nullopt;
}

// Toner tags are whole percents. A missing tag stays empty. An out-of-range
// value is not reported as a percent, including the unverified drum-scale
// reading of 10000.
inline std::optional<int> BrotherTonerPercent(const std::vector<BrotherMaintenanceRecord>& records,
                                              uint8_t tag) {
  const auto value = FindBrotherMaintenanceTag(records, tag);
  if (!value || *value > 100) {
    return std::nullopt;
  }
  return static_cast<int>(*value);
}

inline std::optional<int64_t> BrotherCounterValue(
    const std::vector<BrotherMaintenanceRecord>& records, uint8_t tag) {
  const auto value = FindBrotherMaintenanceTag(records, tag);
  if (!value) {
    return std::nullopt;
  }
  return static_cast<int64_t>(*value);
}

// Verified HL-L3280CDW tags only. Tag 0x81 black, 0x82 cyan, 0x83 magenta, 0x84 yellow.
inline void ApplyBrotherTonerRecords(BrotherMaintenance& maintenance,
                                     const std::vector<BrotherMaintenanceRecord>& records) {
  maintenance.black_toner_percent = BrotherTonerPercent(records, 0x81);
  maintenance.cyan_toner_percent = BrotherTonerPercent(records, 0x82);
  maintenance.magenta_toner_percent = BrotherTonerPercent(records, 0x83);
  maintenance.yellow_toner_percent = BrotherTonerPercent(records, 0x84);
}

// Tag 0x00 total, 0x02 color, 0x01 black-and-white. Not prtMarkerLifeCount.
inline void ApplyBrotherPageRecords(BrotherMaintenance& maintenance,
                                    const std::vector<BrotherMaintenanceRecord>& records) {
  maintenance.pages_total = BrotherCounterValue(records, 0x00);
  maintenance.pages_color = BrotherCounterValue(records, 0x02);
  maintenance.pages_black_white = BrotherCounterValue(records, 0x01);
}

// Tag 0x88 belt remaining pages, 0x73 fuser remaining pages.
inline void ApplyBrotherPartsRecords(BrotherMaintenance& maintenance,
                                     const std::vector<BrotherMaintenanceRecord>& records) {
  maintenance.belt_remaining_pages = BrotherCounterValue(records, 0x88);
  maintenance.fuser_remaining_pages = BrotherCounterValue(records, 0x73);
}

}  // namespace skp_printer

#endif  // SKP_PRINTER_BROTHER_MAINTENANCE_H_
