#ifndef SKP_PRINTER_BROTHER_ERROR_HISTORY_H_
#define SKP_PRINTER_BROTHER_ERROR_HISTORY_H_

#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace skp_printer {

inline constexpr std::size_t kBrotherErrorDescriptionMax = 160;
inline constexpr int kBrotherErrorHistoryMaxRows = 10;

struct BrotherErrorHistoryEntry {
  int index = 0;
  std::string description;
};

struct BrotherErrorHistory {
  bool available = false;
  std::vector<BrotherErrorHistoryEntry> entries;
};

// Trim, collapse whitespace, and drop non-printable bytes. An empty result is
// an empty row, not a recorded error. Text is capped at 160 characters.
inline std::optional<std::string> NormalizeBrotherErrorDescription(const std::string& raw) {
  std::string out;
  bool pending_space = false;
  for (unsigned char c : raw) {
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      if (!out.empty()) {
        pending_space = true;
      }
      continue;
    }
    if (c < 32 || c > 126) {
      continue;
    }
    if (pending_space) {
      if (out.size() >= kBrotherErrorDescriptionMax) {
        break;
      }
      out.push_back(' ');
      pending_space = false;
    }
    if (out.size() >= kBrotherErrorDescriptionMax) {
      break;
    }
    out.push_back(static_cast<char>(c));
  }
  if (out.empty()) {
    return std::nullopt;
  }
  return out;
}

// row_texts[0] is SNMP row 1. Rows after the first 10 are ignored. Empty
// descriptions are omitted, so a count of 10 can produce one entry.
inline std::vector<BrotherErrorHistoryEntry> CollectBrotherErrorHistoryRows(
    const std::vector<std::string>& row_texts) {
  std::vector<BrotherErrorHistoryEntry> entries;
  const std::size_t limit =
      row_texts.size() < static_cast<std::size_t>(kBrotherErrorHistoryMaxRows)
          ? row_texts.size()
          : static_cast<std::size_t>(kBrotherErrorHistoryMaxRows);
  for (std::size_t i = 0; i < limit; ++i) {
    auto text = NormalizeBrotherErrorDescription(row_texts[i]);
    if (!text) {
      continue;
    }
    BrotherErrorHistoryEntry entry;
    entry.index = static_cast<int>(i + 1);
    entry.description = std::move(*text);
    entries.push_back(std::move(entry));
  }
  return entries;
}

}  // namespace skp_printer

#endif  // SKP_PRINTER_BROTHER_ERROR_HISTORY_H_
