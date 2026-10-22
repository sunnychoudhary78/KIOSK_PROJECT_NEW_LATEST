#include "brother_hl_l3280cdw.h"

#include <cctype>

namespace skp_printer {
namespace {

// Printer-MIB prtMarkerLifeCount.1.1
constexpr const char* kPageCounterOid = "1.3.6.1.2.1.43.10.2.1.4.1.1";

// Host-Resources-MIB hrPrinterDetectedErrorState
constexpr const char* kDetectedErrorOid = "1.3.6.1.2.1.25.3.5.1.2.1";

// prtMarkerSuppliesLevel / MaxCapacity / Description for markers 1..4 (CMYK-ish)
constexpr const char* kSupplyLevelFmt = "1.3.6.1.2.1.43.11.1.1.9.1.";
constexpr const char* kSupplyMaxFmt = "1.3.6.1.2.1.43.11.1.1.8.1.";
constexpr const char* kSupplyDescFmt = "1.3.6.1.2.1.43.11.1.1.6.1.";

// prtInputName / CurrentLevel / MaxCapacity tray 1
constexpr const char* kTrayNameOid = "1.3.6.1.2.1.43.8.2.1.13.1.1";
constexpr const char* kTrayLevelOid = "1.3.6.1.2.1.43.8.2.1.10.1.1";
constexpr const char* kTrayMaxOid = "1.3.6.1.2.1.43.8.2.1.9.1.1";

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
  // Brother often returns -2/-3 sentinels on standard MIB.
  if (level < 0 || max_capacity <= 0) {
    return std::nullopt;
  }
  int pct = static_cast<int>((level * 100) / max_capacity);
  if (pct < 0) pct = 0;
  if (pct > 100) pct = 100;
  return pct;
}

}  // namespace

BrotherHlL3280CdwProfile::BrotherHlL3280CdwProfile(std::string host, std::string community)
    : client_(std::move(host), std::move(community)) {}

std::optional<int64_t> BrotherHlL3280CdwProfile::ReadPageCounter() const {
  auto oid = SnmpOid::Parse(kPageCounterOid);
  if (!oid) {
    return std::nullopt;
  }
  return client_.GetInteger(*oid);
}

BrotherSnmpSnapshot BrotherHlL3280CdwProfile::Read() const {
  BrotherSnmpSnapshot snap;
  auto counter = ReadPageCounter();
  if (!counter) {
    snap.snmp_ok = false;
    snap.last_error_code = "SNMP_TIMEOUT";
    return snap;
  }
  snap.snmp_ok = true;
  snap.page_counter = counter;

  auto err_oid = SnmpOid::Parse(kDetectedErrorOid);
  if (err_oid) {
    // OCTET STRING bitfield; treat presence of non-zero as error hint.
    auto bits = client_.GetOctetString(*err_oid);
    if (bits && !bits->empty()) {
      unsigned char b = static_cast<unsigned char>((*bits)[0]);
      // hrPrinterDetectedErrorState bits (RFC 2790): lowPaper, noPaper, lowToner,
      // noToner, doorOpen, jammed, offline, serviceRequested, ...
      if (b & 0x40) {
        snap.snmp_state = "jam";
        snap.last_error_code = "PAPER_JAM";
      } else if (b & 0x20) {
        snap.snmp_state = "paper_out";
        snap.last_error_code = "PAPER_OUT";
      } else if (b & 0x08) {
        snap.snmp_state = "toner_low";
        snap.last_error_code = "NO_TONER";
      } else if (b & 0x10) {
        snap.snmp_state = "toner_low";
        snap.last_error_code = "TONER_LOW";
      } else if (b & 0x02) {
        snap.snmp_state = "offline";
        snap.last_error_code = "OFFLINE";
      }
    }
  }

  for (int i = 1; i <= 4; ++i) {
    auto level_oid = SnmpOid::Parse(std::string(kSupplyLevelFmt) + std::to_string(i));
    auto max_oid = SnmpOid::Parse(std::string(kSupplyMaxFmt) + std::to_string(i));
    auto desc_oid = SnmpOid::Parse(std::string(kSupplyDescFmt) + std::to_string(i));
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
  auto tray_name_oid = SnmpOid::Parse(kTrayNameOid);
  tray.name = tray_name_oid ? client_.GetOctetString(*tray_name_oid).value_or("Tray 1") : "Tray 1";
  if (tray.name.empty()) {
    tray.name = "Tray 1";
  }
  auto tray_level_oid = SnmpOid::Parse(kTrayLevelOid);
  auto tray_max_oid = SnmpOid::Parse(kTrayMaxOid);
  if (tray_level_oid && tray_max_oid) {
    auto level = client_.GetInteger(*tray_level_oid);
    auto maxc = client_.GetInteger(*tray_max_oid);
    if (level && maxc) {
      tray.level_percent = LevelPercent(*level, *maxc);
    }
  }
  tray.status = "ok";
  snap.trays.push_back(std::move(tray));

  return snap;
}

}  // namespace skp_printer
