#include "brother_error_history.h"

#include <cstdio>
#include <string>

namespace {

int g_failures = 0;

void Expect(bool ok, const char* message) {
  if (!ok) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    g_failures += 1;
  }
}

}  // namespace

int main() {
  using skp_printer::CollectBrotherErrorHistoryRows;
  using skp_printer::NormalizeBrotherErrorDescription;
  using skp_printer::kBrotherErrorDescriptionMax;

  const auto collapsed = NormalizeBrotherErrorDescription("Cannot Print  ZC");
  Expect(collapsed && *collapsed == "Cannot Print ZC", "double space collapses");

  Expect(!NormalizeBrotherErrorDescription(""), "empty description is omitted");
  Expect(!NormalizeBrotherErrorDescription(" \t\r\n "), "whitespace-only description is omitted");

  const auto dropped = NormalizeBrotherErrorDescription(std::string("Cannot\x01 Print"));
  Expect(dropped && *dropped == "Cannot Print", "non-printable byte is dropped");

  const std::string long_text(kBrotherErrorDescriptionMax + 1, 'A');
  const auto capped = NormalizeBrotherErrorDescription(long_text);
  Expect(capped && capped->size() == kBrotherErrorDescriptionMax, "description is capped at 160");

  std::vector<std::string> rows(10);
  rows[0] = "Cannot Print  ZC";
  rows.push_back("ignored eleventh row");
  const auto entries = CollectBrotherErrorHistoryRows(rows);
  Expect(entries.size() == 1, "only the non-empty row is kept");
  Expect(!entries.empty() && entries[0].index == 1, "kept row keeps index 1");
  Expect(!entries.empty() && entries[0].description == "Cannot Print ZC",
         "kept row is normalized");

  if (g_failures != 0) {
    std::fprintf(stderr, "brother error history selftest failed: %d\n", g_failures);
    return 1;
  }
  std::printf("brother error history selftest ok\n");
  return 0;
}
