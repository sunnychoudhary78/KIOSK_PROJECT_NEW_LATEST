#ifndef SKP_PRINTER_SNMP_POLL_CACHE_H_
#define SKP_PRINTER_SNMP_POLL_CACHE_H_

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>

#include "brother_hl_l3280cdw.h"

namespace skp_printer {

struct SnmpPollTelemetry {
  BrotherSnmpSnapshot snapshot;
  bool configured = false;
  bool snmp_reachable = false;
  int consecutive_failures = 0;
  int64_t last_success_epoch_ms = 0;
  int64_t last_attempt_epoch_ms = 0;
  std::string last_poll_error;
};

class SnmpPollCache {
 public:
  static SnmpPollCache& Instance();

  void Configure(std::string host, std::string community, int interval_ms, int timeout_ms,
                 int failure_threshold);
  void Stop();

  SnmpPollTelemetry Get() const;
  SnmpPollTelemetry RefreshNow();

 private:
  SnmpPollCache() = default;
  ~SnmpPollCache();
  SnmpPollCache(const SnmpPollCache&) = delete;
  SnmpPollCache& operator=(const SnmpPollCache&) = delete;

  void EnsureThread();
  void Loop();
  void PollOnce();

  mutable std::mutex mu_;
  std::string host_;
  std::string community_;
  int interval_ms_ = 2000;
  int timeout_ms_ = 3000;
  int failure_threshold_ = 3;
  SnmpPollTelemetry telemetry_;
  std::atomic<bool> running_{false};
  std::thread worker_;
};

}  // namespace skp_printer

#endif  // SKP_PRINTER_SNMP_POLL_CACHE_H_
