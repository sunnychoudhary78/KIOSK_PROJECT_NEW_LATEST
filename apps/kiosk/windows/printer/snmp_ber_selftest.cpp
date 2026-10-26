#include "snmp_ber.h"

#include <cstdio>

int main() {
  const uint8_t counter40[] = {0x28};
  auto counter = skp_printer::DecodeSnmpInteger(0x41, counter40, 1);
  if (!counter || *counter != 40) {
    std::fprintf(stderr, "Counter32 40 failed\n");
    return 1;
  }

  const uint8_t counter128[] = {0x00, 0x00, 0x00, 0x80};
  auto high = skp_printer::DecodeSnmpInteger(0x41, counter128, 4);
  if (!high || *high != 128) {
    std::fprintf(stderr, "Counter32 high bit failed\n");
    return 1;
  }

  const uint8_t minus_one[] = {0xFF};
  auto negative = skp_printer::DecodeSnmpInteger(0x02, minus_one, 1);
  if (!negative || *negative != -1) {
    std::fprintf(stderr, "signed INTEGER -1 failed\n");
    return 1;
  }

  if (skp_printer::DecodeSnmpInteger(0x41, nullptr, 0)) {
    std::fprintf(stderr, "empty Counter32 should fail\n");
    return 1;
  }
  if (skp_printer::DecodeSnmpInteger(0x04, counter40, 1)) {
    std::fprintf(stderr, "octet string tag should fail\n");
    return 1;
  }

  const uint8_t gauge[] = {0x01, 0x00};
  auto gauge_value = skp_printer::DecodeSnmpInteger(0x42, gauge, 2);
  if (!gauge_value || *gauge_value != 256) {
    std::fprintf(stderr, "Gauge32 failed\n");
    return 1;
  }

  const uint8_t ticks[] = {0x00, 0x0A};
  auto ticks_value = skp_printer::DecodeSnmpInteger(0x43, ticks, 2);
  if (!ticks_value || *ticks_value != 10) {
    std::fprintf(stderr, "TimeTicks failed\n");
    return 1;
  }

  auto empty_octet = skp_printer::CopySnmpOctetBytes(nullptr, 0);
  if (!empty_octet || !empty_octet->empty()) {
    std::fprintf(stderr, "empty OCTET STRING should succeed\n");
    return 1;
  }

  const uint8_t text[] = {'Z', 'C'};
  auto copied = skp_printer::CopySnmpOctetBytes(text, 2);
  if (!copied || *copied != "ZC") {
    std::fprintf(stderr, "OCTET STRING copy failed\n");
    return 1;
  }

  std::printf("snmp ber selftest ok\n");
  return 0;
}
