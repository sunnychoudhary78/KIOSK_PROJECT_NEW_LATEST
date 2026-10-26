#include "brother_hl_l3280cdw.h"

#include <cctype>
#include <cstdio>
#include <sstream>
#include <vector>

namespace skp_printer {
namespace {

std::string GuessColor(const std::string& desc) {
  std::string lower = desc;
  for (char& c : lower) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  if (lower.find("cyan") != std::string::npos) return "cyan";
  if (lower.find("magenta") != std::string::npos) return "magenta";
  if (lower.find("yellow") != std::string::npos) return "yellow";
  if (lower.find("black") != std::string::npos || lower.find("bk") != std::string::npos) {
    return "black";
  }
  return "unknown";
}

std::optional<int> LevelPercent(int64_t level, int64_t max_capacity) {
  if (level < 0 || max_capacity <= 0) {
    return std::nullopt;
  }
  int pct = static_cast<int>((level * 100) / max_capacity);
  if (pct < 0) pct = 0;
  if (pct > 100) pct = 100;
  return pct;
}

void ConsumeMaintenanceOid(
    const SnmpV2cClient& client, const char* oid, bool& any, BrotherMaintenance& maintenance,
    void (*apply)(BrotherMaintenance&, const std::vector<BrotherMaintenanceRecord>&)) {
  auto parsed = SnmpOid::Parse(oid);
  if (!parsed) {
    return;
  }
  auto octets = client.GetOctetString(*parsed);
  if (!octets) {
    return;
  }
  any = true;
  const auto* bytes = reinterpret_cast<const uint8_t*>(octets->data());
  apply(maintenance, DecodeBrotherMaintenanceRecords(bytes, octets->size()));
}

}  // namespace

BrotherHlL3280CdwProfile::BrotherHlL3280CdwProfile(std::string host, std::string community,
                                                   int timeout_ms)
    : client_(std::move(host), std::move(community), timeout_ms) {}

std::string BrotherHlL3280CdwProfile::StatusLabel(int hr_status) {
  switch (hr_status) {
    case 1:
      return "other";
    case 2:
      return "unknown";
    case 3:
      return "idle";
    case 4:
      return "printing";
    case 5:
      return "warmup";
    default:
      return "other";
  }
}

std::string BrotherHlL3280CdwProfile::OctetsToHex(const std::string& raw_octets) {
  if (raw_octets.empty()) {
    return {};
  }
  std::ostringstream oss;
  for (unsigned char c : raw_octets) {
    char buf[8];
    std::snprintf(buf, sizeof(buf), "%02X", static_cast<unsigned>(c));
    oss << buf;
  }
  return oss.str();
}

BrotherErrorFlagsDecoded BrotherHlL3280CdwProfile::DecodeErrorFlags(
    const std::string& raw_octets) {
  BrotherErrorFlagsDecoded flags;
  if (raw_octets.empty()) {
    return flags;
  }
  // RFC 2790: bit 0 = MSB of first octet.
  // lowPaper(0)=0x80 noPaper(1)=0x40 lowToner(2)=0x20 noToner(3)=0x10
  // doorOpen(4)=0x08 jammed(5)=0x04 offline(6)=0x02 serviceRequested(7)=0x01
  const unsigned char b0 = static_cast<unsigned char>(raw_octets[0]);
  flags.low_paper = (b0 & 0x80) != 0;
  flags.no_paper = (b0 & 0x40) != 0;
  flags.low_toner = (b0 & 0x20) != 0;
  flags.no_toner = (b0 & 0x10) != 0;
  flags.door_open = (b0 & 0x08) != 0;
  flags.jammed = (b0 & 0x04) != 0;
  flags.offline_bit = (b0 & 0x02) != 0;
  return flags;
}

std::optional<int64_t> BrotherHlL3280CdwProfile::ReadPageCounter() const {
  auto oid = SnmpOid::Parse(BrotherOids::kPrtMarkerLifeCount);
  if (!oid) {
    return std::nullopt;
  }
  auto value = client_.GetInteger(*oid);
  if (!value || *value < 0) {
    return std::nullopt;
  }
  return value;
}

BrotherSnmpSnapshot BrotherHlL3280CdwProfile::Read() const {
  BrotherSnmpSnapshot snap;

  auto status_oid = SnmpOid::Parse(BrotherOids::kHrPrinterStatus);
  auto counter = ReadPageCounter();
  if (!status_oid) {
    snap.poll_error = "oid_parse";
    return snap;
  }

  auto hr_status = client_.GetInteger(*status_oid);
  if (!hr_status && !counter) {
    snap.snmp_ok = false;
    snap.poll_error = "snmp_timeout";
    snap.last_error_code = "SNMP_TIMEOUT";
    return snap;
  }

  snap.snmp_ok = true;
  if (hr_status) {
    snap.hr_printer_status = static_cast<int>(*hr_status);
    snap.hr_printer_status_label = StatusLabel(*snap.hr_printer_status);
  }
  if (counter) {
    snap.page_counter = counter;
  }

  auto err_oid = SnmpOid::Parse(BrotherOids::kHrPrinterDetectedErrorState);
  if (err_oid) {
    auto bits = client_.GetOctetString(*err_oid);
    if (bits) {
      snap.error_flags_hex = OctetsToHex(*bits);
      snap.error_flags = DecodeErrorFlags(*bits);
    }
  }

  // Never set state=offline from offline_bit alone (SNMP may still succeed).
  if (snap.error_flags.jammed) {
    snap.snmp_state = "jam";
    snap.last_error_code = "PAPER_JAM";
  } else if (snap.error_flags.no_paper) {
    snap.snmp_state = "paper_out";
    snap.last_error_code = "PAPER_OUT";
  } else if (snap.error_flags.no_toner) {
    snap.snmp_state = "toner_low";
    snap.last_error_code = "NO_TONER";
  } else if (snap.error_flags.low_toner) {
    snap.snmp_state = "toner_low";
    snap.last_error_code = "TONER_LOW";
  } else if (snap.hr_printer_status == 4 || snap.hr_printer_status == 5) {
    snap.snmp_state = "printing";
  } else if (snap.hr_printer_status == 3) {
    snap.snmp_state = "ready";
  }

  for (int i = 1; i <= 4; ++i) {
    auto level_oid = SnmpOid::Parse(std::string(BrotherOids::kSupplyLevelFmt) + std::to_string(i));
    auto max_oid = SnmpOid::Parse(std::string(BrotherOids::kSupplyMaxFmt) + std::to_string(i));
    auto desc_oid = SnmpOid::Parse(std::string(BrotherOids::kSupplyDescFmt) + std::to_string(i));
    if (!level_oid || !max_oid) {
      continue;
    }
    auto level = client_.GetInteger(*level_oid);
    if (!level) {
      continue;
    }
    auto maxc = client_.GetInteger(*max_oid);
    BrotherSupplyReading supply;
    supply.name = desc_oid ? client_.GetOctetString(*desc_oid).value_or("Toner " + std::to_string(i))
                           : ("Toner " + std::to_string(i));
    if (supply.name.empty()) {
      supply.name = "Toner " + std::to_string(i);
    }
    supply.color = GuessColor(supply.name);
    supply.level_percent = LevelPercent(*level, maxc.value_or(-1));
    if (*level == -3) {
      supply.status = "some_remaining";
    } else if (*level == -2) {
      supply.status = "unknown";
    } else if (supply.level_percent && *supply.level_percent <= 10) {
      supply.status = "low";
    } else {
      supply.status = "ok";
    }
    snap.supplies.push_back(std::move(supply));
  }

  BrotherTrayReading tray;
  auto tray_name_oid = SnmpOid::Parse(BrotherOids::kTrayNameOid);
  tray.name = tray_name_oid ? client_.GetOctetString(*tray_name_oid).value_or("Tray 1") : "Tray 1";
  if (tray.name.empty()) {
    tray.name = "Tray 1";
  }
  auto tray_level_oid = SnmpOid::Parse(BrotherOids::kTrayLevelOid);
  auto tray_max_oid = SnmpOid::Parse(BrotherOids::kTrayMaxOid);
  if (tray_level_oid && tray_max_oid) {
    auto level = client_.GetInteger(*tray_level_oid);
    auto maxc = client_.GetInteger(*tray_max_oid);
    if (level && maxc) {
      tray.level_percent = LevelPercent(*level, *maxc);
    }
  }
  tray.status = snap.error_flags.no_paper ? "empty" : "ok";
  snap.trays.push_back(std::move(tray));

  ReadMaintenance(snap);
  return snap;
}

std::optional<int64_t> BrotherHlL3280CdwProfile::ReadErrorHistoryCount() const {
  auto oid = SnmpOid::Parse(BrotherOids::kBrotherErrorHistoryCount);
  if (!oid) {
    return std::nullopt;
  }
  auto value = client_.GetInteger(*oid);
  if (!value || *value < 0) {
    return std::nullopt;
  }
  return value;
}

std::optional<std::string> BrotherHlL3280CdwProfile::ReadErrorHistoryDescription(int row) const {
  if (row < 1 || row > kBrotherErrorHistoryMaxRows) {
    return std::nullopt;
  }
  auto oid = SnmpOid::Parse(std::string(BrotherOids::kBrotherErrorHistoryDescriptionPrefix) +
                            std::to_string(row));
  if (!oid) {
    return std::nullopt;
  }
  return client_.GetOctetString(*oid);
}

void BrotherHlL3280CdwProfile::ReadMaintenance(BrotherSnmpSnapshot& snap) const {
  bool any = false;
  ConsumeMaintenanceOid(client_, BrotherOids::kBrotherTonerInfo, any, snap.maintenance,
                        ApplyBrotherTonerRecords);
  ConsumeMaintenanceOid(client_, BrotherOids::kBrotherPageInfo, any, snap.maintenance,
                        ApplyBrotherPageRecords);
  ConsumeMaintenanceOid(client_, BrotherOids::kBrotherPartsInfo, any, snap.maintenance,
                        ApplyBrotherPartsRecords);
  snap.maintenance.available = any;
}

}  // namespace skp_printer
