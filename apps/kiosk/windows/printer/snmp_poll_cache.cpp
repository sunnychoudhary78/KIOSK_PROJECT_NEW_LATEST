#include "snmp_poll_cache.h"

#include <algorithm>
#include <chrono>

namespace skp_printer {
namespace {

int64_t NowEpochMs() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
}

constexpr int64_t kErrorHistoryIntervalMs = 60000;

}  // namespace

SnmpPollCache& SnmpPollCache::Instance() {
  static SnmpPollCache instance;
  return instance;
}

SnmpPollCache::~SnmpPollCache() {
  Stop();
}

void SnmpPollCache::Configure(std::string host, std::string community, int interval_ms,
                              int timeout_ms, int failure_threshold) {
  bool start = false;
  {
    std::lock_guard<std::mutex> lock(mu_);
    host_ = std::move(host);
    community_ = std::move(community);
    interval_ms_ = interval_ms > 0 ? interval_ms : 2000;
    timeout_ms_ = timeout_ms > 0 ? timeout_ms : 3000;
    failure_threshold_ = failure_threshold > 0 ? failure_threshold : 3;
    start = !host_.empty() && !community_.empty();
    telemetry_.configured = start;
  }
  if (start) {
    EnsureThread();
  } else {
    Stop();
  }
}

void SnmpPollCache::Stop() {
  running_ = false;
  wake_cv_.notify_all();
  if (worker_.joinable()) {
    worker_.join();
  }
}

void SnmpPollCache::EnsureThread() {
  if (running_) {
    return;
  }
  running_ = true;
  worker_ = std::thread([this]() { Loop(); });
}

void SnmpPollCache::Loop() {
  while (running_) {
    std::vector<std::function<void(const SnmpPollTelemetry&)>> pending;
    {
      std::lock_guard<std::mutex> lock(wake_mu_);
      if (counter_requested_) {
        counter_requested_ = false;
        pending.swap(counter_callbacks_);
      }
    }
    if (!pending.empty()) {
      PollPageCounter();
      const SnmpPollTelemetry telem = Get();
      for (auto& callback : pending) {
        callback(telem);
      }
      continue;
    }

    PollOnce();

    bool counter_waiting = false;
    {
      std::lock_guard<std::mutex> lock(wake_mu_);
      counter_waiting = counter_requested_;
    }
    if (!counter_waiting) {
      PollErrorHistoryStep();
    }

    int sleep_ms = 2000;
    {
      std::lock_guard<std::mutex> lock(mu_);
      sleep_ms = interval_ms_;
    }
    std::unique_lock<std::mutex> wake_lock(wake_mu_);
    wake_cv_.wait_for(wake_lock, std::chrono::milliseconds(sleep_ms), [this] {
      return !running_.load() || counter_requested_;
    });
  }

  std::vector<std::function<void(const SnmpPollTelemetry&)>> leftover;
  {
    std::lock_guard<std::mutex> lock(wake_mu_);
    leftover.swap(counter_callbacks_);
    counter_requested_ = false;
  }
  if (!leftover.empty()) {
    const SnmpPollTelemetry telem = Get();
    for (auto& callback : leftover) {
      callback(telem);
    }
  }
}

void SnmpPollCache::PollOnce() {
  std::unique_lock<std::mutex> poll_lock(poll_mu_);
  if (poll_in_progress_) {
    return;
  }
  poll_in_progress_ = true;
  PollOnceBody();
  poll_in_progress_ = false;
  poll_cv_.notify_all();
}

void SnmpPollCache::PollOnceBody() {
  std::string host;
  std::string community;
  int timeout_ms = 3000;
  int failure_threshold = 3;
  {
    std::lock_guard<std::mutex> lock(mu_);
    host = host_;
    community = community_;
    timeout_ms = timeout_ms_;
    failure_threshold = failure_threshold_;
    if (host.empty() || community.empty()) {
      telemetry_.configured = false;
      telemetry_.snmp_reachable = false;
      return;
    }
    telemetry_.configured = true;
    telemetry_.last_attempt_epoch_ms = NowEpochMs();
  }

  BrotherHlL3280CdwProfile profile(host, community, timeout_ms);
  auto snap = profile.Read();

  std::lock_guard<std::mutex> lock(mu_);
  telemetry_.last_attempt_epoch_ms = NowEpochMs();
  if (snap.snmp_ok) {
    auto history = std::move(telemetry_.snapshot.error_history);
    telemetry_.snapshot = std::move(snap);
    telemetry_.snapshot.error_history = std::move(history);
    telemetry_.consecutive_failures = 0;
    telemetry_.last_success_epoch_ms = telemetry_.last_attempt_epoch_ms;
    telemetry_.last_poll_error.clear();
    telemetry_.snmp_reachable = true;
  } else {
    telemetry_.consecutive_failures += 1;
    telemetry_.last_poll_error = snap.poll_error.empty() ? "snmp_timeout" : snap.poll_error;
    telemetry_.snmp_reachable = telemetry_.consecutive_failures < failure_threshold;
    // Keep last successful snapshot for diagnostics. Callers must not treat it as a live read.
    // Drop Brother maintenance so a failed poll cannot leave the previous percents looking current.
    // page_counter is unchanged and still comes from prtMarkerLifeCount.
    telemetry_.snapshot.snmp_ok = false;
    telemetry_.snapshot.poll_error = telemetry_.last_poll_error;
    telemetry_.snapshot.maintenance = {};
  }
}

void SnmpPollCache::PublishErrorHistory(BrotherErrorHistory history, int64_t now_ms) {
  std::lock_guard<std::mutex> lock(mu_);
  telemetry_.snapshot.error_history = std::move(history);
  history_pending_.clear();
  history_phase_ = ErrorHistoryPhase::kIdle;
  history_due_epoch_ms_ = now_ms + kErrorHistoryIntervalMs;
}

void SnmpPollCache::FailErrorHistory(int64_t now_ms) {
  BrotherErrorHistory cleared;
  PublishErrorHistory(std::move(cleared), now_ms);
}

void SnmpPollCache::PollErrorHistoryStep() {
  const int64_t now = NowEpochMs();
  if (history_phase_ == ErrorHistoryPhase::kIdle && now < history_due_epoch_ms_) {
    return;
  }
  if (history_phase_ == ErrorHistoryPhase::kIdle) {
    history_phase_ = ErrorHistoryPhase::kCount;
    history_pending_.clear();
  }

  std::string host;
  std::string community;
  int timeout_ms = 3000;
  {
    std::lock_guard<std::mutex> lock(mu_);
    host = host_;
    community = community_;
    timeout_ms = timeout_ms_;
    if (host.empty() || community.empty()) {
      return;
    }
  }

  BrotherHlL3280CdwProfile profile(host, community, timeout_ms);
  std::unique_lock<std::mutex> poll_lock(poll_mu_);
  if (poll_in_progress_) {
    return;
  }
  poll_in_progress_ = true;

  if (history_phase_ == ErrorHistoryPhase::kCount) {
    auto count = profile.ReadErrorHistoryCount();
    poll_in_progress_ = false;
    poll_cv_.notify_all();
    poll_lock.unlock();
    if (!count) {
      FailErrorHistory(NowEpochMs());
      return;
    }
    if (*count == 0) {
      BrotherErrorHistory history;
      history.available = true;
      PublishErrorHistory(std::move(history), NowEpochMs());
      return;
    }
    const int64_t capped = std::min<int64_t>(*count, kBrotherErrorHistoryMaxRows);
    history_rows_ = static_cast<int>(capped);
    history_row_ = 1;
    history_pending_.clear();
    history_phase_ = ErrorHistoryPhase::kRows;
    return;
  }

  auto text = profile.ReadErrorHistoryDescription(history_row_);
  poll_in_progress_ = false;
  poll_cv_.notify_all();
  poll_lock.unlock();
  if (!text) {
    FailErrorHistory(NowEpochMs());
    return;
  }
  auto normalized = NormalizeBrotherErrorDescription(*text);
  if (normalized) {
    BrotherErrorHistoryEntry entry;
    entry.index = history_row_;
    entry.description = std::move(*normalized);
    history_pending_.push_back(std::move(entry));
  }
  history_row_ += 1;
  if (history_row_ > history_rows_) {
    BrotherErrorHistory history;
    history.available = true;
    history.entries = std::move(history_pending_);
    PublishErrorHistory(std::move(history), NowEpochMs());
  }
}

SnmpPollTelemetry SnmpPollCache::Get() const {
  std::lock_guard<std::mutex> lock(mu_);
  return telemetry_;
}

SnmpPollTelemetry SnmpPollCache::RefreshNow() {
  {
    std::unique_lock<std::mutex> poll_lock(poll_mu_);
    if (poll_in_progress_) {
      // Reuse the walk already running. Do not start a second one.
      poll_cv_.wait(poll_lock, [this] { return !poll_in_progress_; });
    } else {
      poll_in_progress_ = true;
      PollOnceBody();
      poll_in_progress_ = false;
      poll_cv_.notify_all();
    }
  }
  return Get();
}

void SnmpPollCache::PollPageCounter() {
  std::unique_lock<std::mutex> poll_lock(poll_mu_);
  if (poll_in_progress_) {
    poll_cv_.wait(poll_lock, [this] { return !poll_in_progress_; });
  }
  poll_in_progress_ = true;
  PollPageCounterBody();
  poll_in_progress_ = false;
  poll_cv_.notify_all();
}

void SnmpPollCache::PollPageCounterBody() {
  std::string host;
  std::string community;
  int timeout_ms = 3000;
  int failure_threshold = 3;
  {
    std::lock_guard<std::mutex> lock(mu_);
    host = host_;
    community = community_;
    timeout_ms = timeout_ms_;
    failure_threshold = failure_threshold_;
    if (host.empty() || community.empty()) {
      telemetry_.configured = false;
      telemetry_.snmp_reachable = false;
      telemetry_.snapshot.snmp_ok = false;
      telemetry_.last_poll_error = "snmp_not_configured";
      return;
    }
    telemetry_.configured = true;
    telemetry_.last_attempt_epoch_ms = NowEpochMs();
  }

  BrotherHlL3280CdwProfile profile(host, community, timeout_ms);
  auto counter = profile.ReadPageCounter();

  std::lock_guard<std::mutex> lock(mu_);
  telemetry_.last_attempt_epoch_ms = NowEpochMs();
  if (counter) {
    telemetry_.snapshot.page_counter = counter;
    telemetry_.snapshot.snmp_ok = true;
    telemetry_.snapshot.poll_error.clear();
    telemetry_.consecutive_failures = 0;
    telemetry_.last_success_epoch_ms = telemetry_.last_attempt_epoch_ms;
    telemetry_.last_poll_error.clear();
    telemetry_.snmp_reachable = true;
  } else {
    telemetry_.consecutive_failures += 1;
    telemetry_.last_poll_error = "snmp_timeout";
    telemetry_.snmp_reachable = telemetry_.consecutive_failures < failure_threshold;
    telemetry_.snapshot.snmp_ok = false;
    telemetry_.snapshot.poll_error = telemetry_.last_poll_error;
  }
}

void SnmpPollCache::RequestPageCounter(
    std::function<void(const SnmpPollTelemetry&)> callback) {
  bool queue = false;
  {
    std::lock_guard<std::mutex> lock(wake_mu_);
    if (running_) {
      counter_callbacks_.push_back(std::move(callback));
      counter_requested_ = true;
      queue = true;
    }
  }
  if (queue) {
    wake_cv_.notify_all();
    return;
  }
  callback(Get());
}

}  // namespace skp_printer
