#include "brother_maintenance.h"

#include <cstdio>

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
  using skp_printer::ApplyBrotherPageRecords;
  using skp_printer::ApplyBrotherPartsRecords;
  using skp_printer::ApplyBrotherTonerRecords;
  using skp_printer::BrotherMaintenance;
  using skp_printer::BrotherTonerPercent;
  using skp_printer::DecodeBrotherMaintenanceRecords;
  using skp_printer::FindBrotherMaintenanceTag;

  // Reconstructed from the verified HL-L3280CDW tag/value pairs and the
  // tag + 01 04 + 4-byte layout. No raw printer capture is stored in the repo.
  // Tag 0x79 (10000) is included only to prove it is not copied into toner.
  const uint8_t toner_blob[] = {
      0x79, 0x01, 0x04, 0x00, 0x00, 0x27, 0x10,  // unverified drum candidate
      0xFF, 0xFF, 0xFF,                          // padding
      0x81, 0x01, 0x04, 0x00, 0x00, 0x00, 0x5A,  // black 90
      0x82, 0x01, 0x04, 0x00, 0x00, 0x00, 0x64,  // cyan 100
      0x83, 0x01, 0x04, 0x00, 0x00, 0x00, 0x64,  // magenta 100
      0x84, 0x01, 0x04, 0x00, 0x00, 0x00, 0x64,  // yellow 100
      0xFF, 0xFF, 0xFF, 0xFF,                    // end
      0x81, 0x01, 0x04, 0x00, 0x00, 0x00, 0x01,  // ignored after terminator
  };
  const uint8_t page_blob[] = {
      0x00, 0x01, 0x04, 0x00, 0x00, 0x00, 0x40,  // total 64
      0xFF, 0xFF, 0xFF, 0x01, 0x01, 0x04, 0x00, 0x00, 0x00, 0x11,  // black-and-white 17
      0x02, 0x01, 0x04, 0x00, 0x00, 0x00, 0x2F,                    // color 47
      0xFF, 0xFF, 0xFF, 0xFF,
  };
  const uint8_t parts_blob[] = {
      0x88, 0x01, 0x04, 0x00, 0x00, 0xC2, 0xDA,  // belt 49882
      0x73, 0x01, 0x04, 0x00, 0x00, 0xC3, 0x10,  // fuser 49936
      0xFF, 0xFF, 0xFF, 0xFF,
  };

  BrotherMaintenance maintenance;
  const auto toner_records = DecodeBrotherMaintenanceRecords(toner_blob, sizeof(toner_blob));
  const auto page_records = DecodeBrotherMaintenanceRecords(page_blob, sizeof(page_blob));
  const auto parts_records = DecodeBrotherMaintenanceRecords(parts_blob, sizeof(parts_blob));
  ApplyBrotherTonerRecords(maintenance, toner_records);
  ApplyBrotherPageRecords(maintenance, page_records);
  ApplyBrotherPartsRecords(maintenance, parts_records);

  const auto drum = FindBrotherMaintenanceTag(toner_records, 0x79);
  Expect(drum && *drum == 10000u, "raw tag 79 is 10000");
  Expect(maintenance.black_toner_percent && *maintenance.black_toner_percent == 90, "black toner 90");
  Expect(maintenance.cyan_toner_percent && *maintenance.cyan_toner_percent == 100, "cyan toner 100");
  Expect(maintenance.magenta_toner_percent && *maintenance.magenta_toner_percent == 100,
         "magenta toner 100");
  Expect(maintenance.yellow_toner_percent && *maintenance.yellow_toner_percent == 100,
         "yellow toner 100");
  Expect(maintenance.pages_total && *maintenance.pages_total == 64, "total pages 64");
  Expect(maintenance.pages_color && *maintenance.pages_color == 47, "color pages 47");
  Expect(maintenance.pages_black_white && *maintenance.pages_black_white == 17,
         "black-and-white pages 17");
  Expect(maintenance.belt_remaining_pages && *maintenance.belt_remaining_pages == 49882,
         "belt remaining 49882");
  Expect(maintenance.fuser_remaining_pages && *maintenance.fuser_remaining_pages == 49936,
         "fuser remaining 49936");

  const uint8_t drum_only[] = {0x79, 0x01, 0x04, 0x00, 0x00, 0x27, 0x10};
  BrotherMaintenance drums;
  ApplyBrotherTonerRecords(drums, DecodeBrotherMaintenanceRecords(drum_only, sizeof(drum_only)));
  Expect(!drums.black_toner_percent && !drums.cyan_toner_percent && !drums.magenta_toner_percent &&
             !drums.yellow_toner_percent,
         "drum candidate is not a toner percent");

  const uint8_t zero_black[] = {0x81, 0x01, 0x04, 0x00, 0x00, 0x00, 0x00};
  BrotherMaintenance zero;
  ApplyBrotherTonerRecords(zero, DecodeBrotherMaintenanceRecords(zero_black, sizeof(zero_black)));
  Expect(zero.black_toner_percent && *zero.black_toner_percent == 0, "zero toner is a real value");
  Expect(!zero.cyan_toner_percent, "missing toner tag stays empty");

  const uint8_t padded_value[] = {0x81, 0x01, 0x04, 0x00, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x5A};
  const auto padded = DecodeBrotherMaintenanceRecords(padded_value, sizeof(padded_value));
  const auto padded_black = FindBrotherMaintenanceTag(padded, 0x81);
  Expect(padded_black && *padded_black == 90u, "padding inside a value is skipped");

  const uint8_t stopped[] = {
      0x81, 0x01, 0x04, 0x00, 0x00, 0x00, 0x5A, 0x00, 0x02, 0x04,
      0x82, 0x01, 0x04, 0x00, 0x00, 0x00, 0x64,
  };
  BrotherMaintenance partial;
  ApplyBrotherTonerRecords(partial, DecodeBrotherMaintenanceRecords(stopped, sizeof(stopped)));
  Expect(partial.black_toner_percent && *partial.black_toner_percent == 90,
         "records before a bad header are kept");
  Expect(!partial.cyan_toner_percent, "records after a bad header are ignored");

  const uint8_t incomplete[] = {0x88, 0x01, 0x04, 0x00, 0x00};
  BrotherMaintenance incomplete_parts;
  ApplyBrotherPartsRecords(incomplete_parts,
                           DecodeBrotherMaintenanceRecords(incomplete, sizeof(incomplete)));
  Expect(!incomplete_parts.belt_remaining_pages, "incomplete value is not zero");

  const uint8_t out_of_range[] = {0x81, 0x01, 0x04, 0x00, 0x00, 0x00, 0x65};
  const auto out_of_range_records =
      DecodeBrotherMaintenanceRecords(out_of_range, sizeof(out_of_range));
  Expect(!BrotherTonerPercent(out_of_range_records, 0x81), "percent above 100 is omitted");

  if (g_failures != 0) {
    std::fprintf(stderr, "brother maintenance selftest failed: %d\n", g_failures);
    return 1;
  }
  std::printf("brother maintenance selftest ok\n");
  return 0;
}
