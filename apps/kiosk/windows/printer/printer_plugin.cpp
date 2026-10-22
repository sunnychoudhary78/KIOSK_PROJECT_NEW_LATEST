#include "printer_plugin.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>

#include "brother_hl_l3280cdw.h"
#include "snmp_poll_cache.h"
#include "spooler_status.h"

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::string StringArg(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return {};
  }
  if (const auto* v = std::get_if<std::string>(&it->second)) {
    return *v;
  }
  return {};
}

int IntArg(const EncodableMap& map, const char* key, int fallback) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return fallback;
  }
  if (const auto* v = std::get_if<int32_t>(&it->second)) {
    return *v;
  }
  if (const auto* v = std::get_if<int64_t>(&it->second)) {
    return static_cast<int>(*v);
  }
  return fallback;
}

bool BoolArg(const EncodableMap& map, const char* key, bool fallback) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return fallback;
  }
  if (const auto* v = std::get_if<bool>(&it->second)) {
    return *v;
  }
  return fallback;
}

EncodableValue NullOrInt(const std::optional<int>& value) {
  if (!value) {
    return EncodableValue();
  }
  return EncodableValue(*value);
}

EncodableValue NullOrInt64(const std::optional<int64_t>& value) {
  if (!value) {
    return EncodableValue();
  }
  return EncodableValue(static_cast<int64_t>(*value));
}

EncodableValue IsoFromEpochMs(int64_t epoch_ms) {
  if (epoch_ms <= 0) {
    return EncodableValue();
  }
  // Dart parses millis via lastSuccessAtMs; also pass ms for simplicity.
  return EncodableValue(static_cast<int64_t>(epoch_ms));
}

class PrinterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto plugin = std::make_unique<PrinterPlugin>();
    auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
        registrar->messenger(), "skp/printer", &flutter::StandardMethodCodec::GetInstance());
    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });
    plugin->method_channel_ = std::move(channel);
    registrar->AddPlugin(std::move(plugin));
  }

  void HandleMethodCall(const flutter::MethodCall<EncodableValue>& call,
                        std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    EncodableMap map = args ? *args : EncodableMap{};

    if (call.method_name() == "configureSnmpPolling") {
      // Accept host/community or snmpHost/snmpCommunity (Dart uses either).
      std::string host = StringArg(map, "host");
      if (host.empty()) {
        host = StringArg(map, "snmpHost");
      }
      std::string community = StringArg(map, "community");
      if (community.empty()) {
        community = StringArg(map, "snmpCommunity");
      }
      const int interval = IntArg(map, "intervalMs", 2000);
      const int timeout = IntArg(map, "timeoutMs", 3000);
      const int threshold = IntArg(map, "failureThreshold", 3);
      skp_printer::SnmpPollCache::Instance().Configure(host, community, interval, timeout,
                                                       threshold);
      EncodableMap out;
      out[EncodableValue("ok")] = EncodableValue(true);
      out[EncodableValue("configured")] = EncodableValue(!host.empty() && !community.empty());
      // Never echo community.
      result->Success(EncodableValue(out));
      return;
    }
    if (call.method_name() == "stopSnmpPolling") {
      skp_printer::SnmpPollCache::Instance().Stop();
      result->Success(EncodableValue(true));
      return;
    }
    if (call.method_name() == "getHealth") {
      result->Success(BuildHealth(map));
      return;
    }
    if (call.method_name() == "getPageCounter") {
      result->Success(BuildPageCounter(map));
      return;
    }
    if (call.method_name() == "getPrinterStatus") {
      result->Success(BuildStatus(map));
      return;
    }
    result->NotImplemented();
  }

 private:
  EncodableValue BuildHealth(const EncodableMap& args) {
    const std::string preferred = StringArg(args, "printerName");
    const std::string model = StringArg(args, "model");

    auto spooler = skp_printer::QuerySpoolerStatus(preferred);
    std::string state = spooler.found ? spooler.state : "offline";
    bool online = spooler.online;
    std::string last_error = spooler.last_error_code;

    auto telem = skp_printer::SnmpPollCache::Instance().Get();
    const auto& snap = telem.snapshot;

    if (telem.configured && snap.snmp_ok && !snap.snmp_state.empty()) {
      // Prefer SNMP-derived paper/jam/printing when poll succeeded.
      if (snap.snmp_state == "paper_out" || snap.snmp_state == "jam" ||
          snap.snmp_state == "printing" || snap.snmp_state == "toner_low") {
        state = snap.snmp_state;
        if (!snap.last_error_code.empty()) {
          last_error = snap.last_error_code;
        }
      } else if (snap.snmp_state == "ready" && state == "ready") {
        state = "ready";
      }
    }

    EncodableList trays;
    EncodableList supplies;
    for (const auto& tray : snap.trays) {
      EncodableMap t;
      t[EncodableValue("name")] = EncodableValue(tray.name);
      t[EncodableValue("levelPercent")] = NullOrInt(tray.level_percent);
      t[EncodableValue("status")] = EncodableValue(tray.status);
      trays.push_back(EncodableValue(t));
    }
    for (const auto& supply : snap.supplies) {
      EncodableMap s;
      s[EncodableValue("name")] = EncodableValue(supply.name);
      s[EncodableValue("color")] = EncodableValue(supply.color);
      s[EncodableValue("levelPercent")] = NullOrInt(supply.level_percent);
      s[EncodableValue("status")] = EncodableValue(supply.status);
      supplies.push_back(EncodableValue(s));
    }

    EncodableMap health;
    health[EncodableValue("state")] = EncodableValue(state);
    health[EncodableValue("online")] = EncodableValue(online);
    health[EncodableValue("printerName")] =
        spooler.name.empty() ? EncodableValue() : EncodableValue(spooler.name);
    health[EncodableValue("model")] =
        EncodableValue(model.empty() ? skp_printer::BrotherHlL3280CdwProfile::kModelName : model);
    health[EncodableValue("trays")] = EncodableValue(trays);
    health[EncodableValue("supplies")] = EncodableValue(supplies);
    health[EncodableValue("pageCounter")] = NullOrInt64(snap.page_counter);
    health[EncodableValue("snmpOk")] = EncodableValue(snap.snmp_ok);
    health[EncodableValue("snmpReachable")] = EncodableValue(telem.snmp_reachable);
    health[EncodableValue("snmpConfigured")] = EncodableValue(telem.configured);
    health[EncodableValue("consecutiveFailures")] = EncodableValue(telem.consecutive_failures);
    health[EncodableValue("lastSuccessAtMs")] = IsoFromEpochMs(telem.last_success_epoch_ms);
    health[EncodableValue("lastAttemptAtMs")] = IsoFromEpochMs(telem.last_attempt_epoch_ms);
    health[EncodableValue("lastPollError")] =
        telem.last_poll_error.empty() ? EncodableValue() : EncodableValue(telem.last_poll_error);
    health[EncodableValue("hrPrinterStatus")] = NullOrInt(snap.hr_printer_status);
    health[EncodableValue("hrPrinterStatusLabel")] =
        snap.hr_printer_status_label.empty() ? EncodableValue()
                                             : EncodableValue(snap.hr_printer_status_label);
    health[EncodableValue("errorFlagsHex")] =
        snap.error_flags_hex.empty() ? EncodableValue() : EncodableValue(snap.error_flags_hex);
    health[EncodableValue("noPaper")] = EncodableValue(snap.error_flags.no_paper);
    health[EncodableValue("jammed")] = EncodableValue(snap.error_flags.jammed);
    health[EncodableValue("offlineBit")] = EncodableValue(snap.error_flags.offline_bit);
    health[EncodableValue("lowPaper")] = EncodableValue(snap.error_flags.low_paper);
    health[EncodableValue("lowToner")] = EncodableValue(snap.error_flags.low_toner);
    health[EncodableValue("noToner")] = EncodableValue(snap.error_flags.no_toner);
    health[EncodableValue("doorOpen")] = EncodableValue(snap.error_flags.door_open);
    health[EncodableValue("spoolerJobsQueued")] = EncodableValue(spooler.jobs_queued);
    health[EncodableValue("spoolerJobsPrinting")] = EncodableValue(spooler.jobs_printing);
    if (spooler.latest_job_id != 0) {
      health[EncodableValue("spoolerLatestJobId")] =
          EncodableValue(static_cast<int64_t>(spooler.latest_job_id));
      health[EncodableValue("spoolerLatestJobStatus")] = EncodableValue(spooler.latest_job_status);
    }
    health[EncodableValue("lastErrorCode")] =
        last_error.empty() ? EncodableValue() : EncodableValue(last_error);
    health[EncodableValue("lastErrorAt")] = EncodableValue();
    return EncodableValue(health);
  }

  EncodableValue BuildPageCounter(const EncodableMap& args) {
    EncodableMap out;
    const bool force_refresh = BoolArg(args, "forceRefresh", false);
    auto telem = skp_printer::SnmpPollCache::Instance().Get();
    if (!telem.configured) {
      out[EncodableValue("ok")] = EncodableValue(false);
      out[EncodableValue("error")] = EncodableValue("snmp_not_configured");
      return EncodableValue(out);
    }
    // Reconcile path: always RefreshNow so timeouts during print do not leave
    // a stale lifetime counter cached for the whole wait loop.
    if (force_refresh || !telem.snapshot.page_counter) {
      telem = skp_printer::SnmpPollCache::Instance().RefreshNow();
    }
    if (telem.snapshot.page_counter) {
      out[EncodableValue("ok")] = EncodableValue(true);
      out[EncodableValue("pageCounter")] =
          EncodableValue(static_cast<int64_t>(*telem.snapshot.page_counter));
      out[EncodableValue("stale")] = EncodableValue(!telem.snapshot.snmp_ok);
      return EncodableValue(out);
    }
    out[EncodableValue("ok")] = EncodableValue(false);
    out[EncodableValue("error")] = EncodableValue(
        telem.last_poll_error.empty() ? "snmp_timeout" : telem.last_poll_error);
    return EncodableValue(out);
  }

  EncodableValue BuildStatus(const EncodableMap& args) {
    const std::string preferred = StringArg(args, "printerName");
    auto spooler = skp_printer::QuerySpoolerStatus(preferred);
    EncodableMap out;
    out[EncodableValue("found")] = EncodableValue(spooler.found);
    out[EncodableValue("online")] = EncodableValue(spooler.online);
    out[EncodableValue("name")] =
        spooler.name.empty() ? EncodableValue() : EncodableValue(spooler.name);
    out[EncodableValue("state")] = EncodableValue(spooler.state);
    out[EncodableValue("lastErrorCode")] =
        spooler.last_error_code.empty() ? EncodableValue()
                                        : EncodableValue(spooler.last_error_code);
    out[EncodableValue("jobsQueued")] = EncodableValue(spooler.jobs_queued);
    out[EncodableValue("jobsPrinting")] = EncodableValue(spooler.jobs_printing);
    if (spooler.latest_job_id != 0) {
      out[EncodableValue("latestJobId")] =
          EncodableValue(static_cast<int64_t>(spooler.latest_job_id));
      out[EncodableValue("latestJobStatus")] = EncodableValue(spooler.latest_job_status);
    }
    return EncodableValue(out);
  }

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> method_channel_;
};

}  // namespace

void PrinterPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  PrinterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
