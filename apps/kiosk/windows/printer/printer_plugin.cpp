#include "printer_plugin.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>

#include "brother_hl_l3280cdw.h"
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
    const std::string host = StringArg(args, "snmpHost");
    const std::string community = StringArg(args, "snmpCommunity");
    const std::string model = StringArg(args, "model");

    auto spooler = skp_printer::QuerySpoolerStatus(preferred);
    std::string state = spooler.found ? spooler.state : "offline";
    bool online = spooler.online;
    std::string last_error = spooler.last_error_code;
    bool snmp_ok = false;
    std::optional<int64_t> page_counter;
    EncodableList trays;
    EncodableList supplies;

    if (!host.empty() && !community.empty()) {
      if (model.empty() || model.find("HL-L3280CDW") != std::string::npos ||
          model.find("Brother") != std::string::npos) {
        skp_printer::BrotherHlL3280CdwProfile profile(host, community);
        auto snap = profile.Read();
        snmp_ok = snap.snmp_ok;
        page_counter = snap.page_counter;
        if (!snap.snmp_state.empty()) {
          state = snap.snmp_state;
          last_error = snap.last_error_code;
        }
        if (!snap.snmp_ok && last_error.empty()) {
          last_error = snap.last_error_code;
        }
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
      }
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
    health[EncodableValue("pageCounter")] = NullOrInt64(page_counter);
    health[EncodableValue("snmpOk")] = EncodableValue(snmp_ok);
    health[EncodableValue("lastErrorCode")] =
        last_error.empty() ? EncodableValue() : EncodableValue(last_error);
    health[EncodableValue("lastErrorAt")] = EncodableValue();
    return EncodableValue(health);
  }

  EncodableValue BuildPageCounter(const EncodableMap& args) {
    const std::string host = StringArg(args, "snmpHost");
    const std::string community = StringArg(args, "snmpCommunity");
    EncodableMap out;
    if (host.empty() || community.empty()) {
      out[EncodableValue("ok")] = EncodableValue(false);
      out[EncodableValue("error")] = EncodableValue("snmp_not_configured");
      return EncodableValue(out);
    }
    skp_printer::BrotherHlL3280CdwProfile profile(host, community);
    auto counter = profile.ReadPageCounter();
    if (!counter) {
      out[EncodableValue("ok")] = EncodableValue(false);
      out[EncodableValue("error")] = EncodableValue("snmp_timeout");
      return EncodableValue(out);
    }
    out[EncodableValue("ok")] = EncodableValue(true);
    out[EncodableValue("pageCounter")] = EncodableValue(static_cast<int64_t>(*counter));
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
