#include "snmp_poll_cache.h"

#include <chrono>

namespace skp_printer {
namespace {

int64_t NowEpochMs() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
}

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
    RefreshNow();
  } else {
    Stop();
  }
}

void SnmpPollCache::Stop() {
  running_ = false;
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
    PollOnce();
    int sleep_ms = 2000;
    {
      std::lock_guard<std::mutex> lock(mu_);
      sleep_ms = interval_ms_;
    }
    for (int i = 0; i < sleep_ms / 50 && running_; ++i) {
      std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
  }
}

void SnmpPollCache::PollOnce() {
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
    telemetry_.snapshot = std::move(snap);
    telemetry_.consecutive_failures = 0;
    telemetry_.last_success_epoch_ms = telemetry_.last_attempt_epoch_ms;
    telemetry_.last_poll_error.clear();
    telemetry_.snmp_reachable = true;
  } else {
    telemetry_.consecutive_failures += 1;
    telemetry_.last_poll_error = snap.poll_error.empty() ? "snmp_timeout" : snap.poll_error;
    telemetry_.snmp_reachable = telemetry_.consecutive_failures < failure_threshold;
    // Keep last successful snapshot for stale reads; mark snmp_ok false on live view.
    telemetry_.snapshot.snmp_ok = false;
    telemetry_.snapshot.poll_error = telemetry_.last_poll_error;
  }
}

SnmpPollTelemetry SnmpPollCache::Get() const {
  std::lock_guard<std::mutex> lock(mu_);
  return telemetry_;
}

SnmpPollTelemetry SnmpPollCache::RefreshNow() {
  PollOnce();
  return Get();
}

}  // namespace skp_printer
