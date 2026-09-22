#include "surveillance_plugin.h"

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <memory>
#include <optional>
#include <string>

#include "surveillance_recorder.h"

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

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

int64_t Int64Arg(const EncodableMap& map, const char* key, int64_t fallback) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return fallback;
  }
  if (const auto* v = std::get_if<int64_t>(&it->second)) {
    return *v;
  }
  if (const auto* v = std::get_if<int32_t>(&it->second)) {
    return *v;
  }
  return fallback;
}

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

class SurveillancePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto plugin = std::make_unique<SurveillancePlugin>();
    auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
        registrar->messenger(), "skp/surveillance", &flutter::StandardMethodCodec::GetInstance());
    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });
    plugin->method_channel_ = std::move(channel);

    auto events = std::make_unique<flutter::EventChannel<EncodableValue>>(
        registrar->messenger(), "skp/surveillance/events",
        &flutter::StandardMethodCodec::GetInstance());
    events->SetStreamHandler(
        std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
            [plugin_pointer = plugin.get()](const EncodableValue*,
                                            std::unique_ptr<flutter::EventSink<EncodableValue>>&&
                                                sink) {
              plugin_pointer->event_sink_ = std::move(sink);
              plugin_pointer->recorder_.SetEventCallback(
                  [plugin_pointer](const skp_surveillance::RecorderEvent& event) {
                    plugin_pointer->Emit(event);
                  });
              return nullptr;
            },
            [plugin_pointer = plugin.get()](const EncodableValue*) {
              plugin_pointer->event_sink_.reset();
              plugin_pointer->recorder_.SetEventCallback(nullptr);
              return nullptr;
            }));
    plugin->event_channel_ = std::move(events);
    registrar->AddPlugin(std::move(plugin));
  }

  SurveillancePlugin() = default;

  void HandleMethodCall(const flutter::MethodCall<EncodableValue>& call,
                        std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    const std::string& method = call.method_name();
    if (method == "start") {
      skp_surveillance::RecorderConfig config;
      if (const auto* args = std::get_if<EncodableMap>(call.arguments())) {
        config.device_id = StringArg(*args, "deviceId");
        config.segment_seconds = IntArg(*args, "segmentSeconds", 600);
        config.width = IntArg(*args, "width", 1280);
        config.height = IntArg(*args, "height", 720);
        config.fps = IntArg(*args, "fps", 15);
        config.bitrate = IntArg(*args, "bitrate", 1200000);
        config.max_cache_bytes = Int64Arg(*args, "maxCacheBytes", 30LL * 1024 * 1024 * 1024);
      }
      const HRESULT hr = recorder_.Start(config);
      if (FAILED(hr)) {
        result->Error("start_failed", "Failed to start surveillance recorder");
        return;
      }
      result->Success();
      return;
    }
    if (method == "stop") {
      recorder_.Stop();
      result->Success();
      return;
    }
    if (method == "pauseForPalm") {
      recorder_.PauseForPalm();
      result->Success();
      return;
    }
    if (method == "resume") {
      const HRESULT hr = recorder_.Resume();
      if (FAILED(hr)) {
        result->Error("resume_failed", "Failed to resume surveillance recorder");
        return;
      }
      result->Success();
      return;
    }
    if (method == "status") {
      result->Success(EncodableValue(recorder_.is_recording()));
      return;
    }
    if (method == "getRootDir") {
      std::string device_id;
      if (const auto* args = std::get_if<EncodableMap>(call.arguments())) {
        device_id = StringArg(*args, "deviceId");
      }
      std::string dir;
      const HRESULT hr = recorder_.GetRootDir(device_id, &dir);
      if (FAILED(hr) || dir.empty()) {
        result->Error("root_dir_failed", "Failed to resolve surveillance root directory");
        return;
      }
      result->Success(EncodableValue(dir));
      return;
    }
    result->NotImplemented();
  }

  void Emit(const skp_surveillance::RecorderEvent& event) {
    if (!event_sink_) {
      return;
    }
    EncodableMap map;
    map[EncodableValue("type")] = EncodableValue(event.type);
    if (!event.path.empty()) {
      map[EncodableValue("path")] = EncodableValue(event.path);
    }
    if (event.type == "SEGMENT_COMPLETED") {
      map[EncodableValue("bytes")] = EncodableValue(event.bytes);
    }
    event_sink_->Success(EncodableValue(map));
  }

 private:
  skp_surveillance::SurveillanceRecorder recorder_;
  std::unique_ptr<flutter::MethodChannel<EncodableValue>> method_channel_;
  std::unique_ptr<flutter::EventChannel<EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<EncodableValue>> event_sink_;
};

}  // namespace

void SurveillancePluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  SurveillancePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
