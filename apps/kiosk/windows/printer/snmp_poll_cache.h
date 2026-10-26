#ifndef SKP_PRINTER_SNMP_POLL_CACHE_H_
#define SKP_PRINTER_SNMP_POLL_CACHE_H_

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

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
  // Full walk. Blocks the caller. Not used from the Flutter method channel.
  SnmpPollTelemetry RefreshNow();

  // Queue a single prtMarkerLifeCount GET on the worker thread.
  // The callback runs on the worker after that GET. Does not block the caller.
  void RequestPageCounter(std::function<void(const SnmpPollTelemetry&)> callback);

 private:
  SnmpPollCache() = default;
  ~SnmpPollCache();
  SnmpPollCache(const SnmpPollCache&) = delete;
  SnmpPollCache& operator=(const SnmpPollCache&) = delete;

  void EnsureThread();
  void Loop();
  void PollOnce();
  void PollPageCounter();
  void PollErrorHistoryStep();
  void PublishErrorHistory(BrotherErrorHistory history, int64_t now_ms);
  void FailErrorHistory(int64_t now_ms);
  // Caller must hold poll_mu_. Does not lock poll_mu_. Locks mu_ only around cache updates.
  void PollOnceBody();
  void PollPageCounterBody();

  // Telemetry only. Never acquire poll_mu_ or wake_mu_ while holding mu_.
  mutable std::mutex mu_;
  // One SNMP walk at a time. Held across the walk so a counter GET and the full poll cannot overlap.
  std::mutex poll_mu_;
  std::condition_variable poll_cv_;
  bool poll_in_progress_ = false;
  // Wakes the worker for a counter-only read. Not held during SNMP.
  std::mutex wake_mu_;
  std::condition_variable wake_cv_;
  bool counter_requested_ = false;
  std::vector<std::function<void(const SnmpPollTelemetry&)>> counter_callbacks_;
  std::string host_;
  std::string community_;
  int interval_ms_ = 2000;
  int timeout_ms_ = 3000;
  int failure_threshold_ = 3;
  SnmpPollTelemetry telemetry_;
  enum class ErrorHistoryPhase { kIdle, kCount, kRows };
  ErrorHistoryPhase history_phase_ = ErrorHistoryPhase::kIdle;
  int history_rows_ = 0;
  int history_row_ = 1;
  std::vector<BrotherErrorHistoryEntry> history_pending_;
  int64_t history_due_epoch_ms_ = 0;
  std::atomic<bool> running_{false};
  std::thread worker_;
};

}  // namespace skp_printer

#endif  // SKP_PRINTER_SNMP_POLL_CACHE_H_
