#include "printer_plugin.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <thread>

#include "spooler_status.h"
#include "usb_helper_client.h"

namespace {

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
    if (call.method_name() == "getUsbSnapshot") {
      const std::string scope = StringArg(map, "scope");
      auto held = std::shared_ptr<flutter::MethodResult<EncodableValue>>(result.release());
      std::thread([held, scope]() {
        held->Success(EncodableValue(skp_printer::RequestUsbSnapshot(scope)));
      }).detach();
      return;
    }
    if (call.method_name() == "resolveUsbPrinter") {
      const auto resolved = skp_printer::ResolveUsbPrinter(StringArg(map, "printerName"));
      EncodableMap out;
      out[EncodableValue("found")] = EncodableValue(resolved.found);
      out[EncodableValue("name")] =
          resolved.name.empty() ? EncodableValue() : EncodableValue(resolved.name);
      out[EncodableValue("port")] =
          resolved.port.empty() ? EncodableValue() : EncodableValue(resolved.port);
      result->Success(EncodableValue(out));
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
    const std::string state = spooler.found ? spooler.state : "offline";
    const std::string last_error = spooler.last_error_code;

    EncodableMap health;
    health[EncodableValue("state")] = EncodableValue(state);
    health[EncodableValue("online")] = EncodableValue(spooler.online);
    health[EncodableValue("printerName")] =
        spooler.name.empty() ? EncodableValue() : EncodableValue(spooler.name);
    health[EncodableValue("model")] =
        model.empty() ? EncodableValue() : EncodableValue(model);
    health[EncodableValue("snmpOk")] = EncodableValue(false);
    health[EncodableValue("snmpReachable")] = EncodableValue(false);
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
