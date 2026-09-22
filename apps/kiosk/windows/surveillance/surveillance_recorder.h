#ifndef RUNNER_SURVEILLANCE_RECORDER_H_
#define RUNNER_SURVEILLANCE_RECORDER_H_

#include <windows.h>

#include <cstdint>
#include <functional>
#include <string>

namespace skp_surveillance {

struct RecorderConfig {
  std::string device_id;
  int segment_seconds = 600;
  int width = 1280;
  int height = 720;
  int fps = 15;
  int bitrate = 1200000;
  int64_t max_cache_bytes = 30LL * 1024 * 1024 * 1024;
};

struct RecorderEvent {
  std::string type;
  std::string path;
  int64_t bytes = 0;
};

class SurveillanceRecorder {
 public:
  using EventCallback = std::function<void(const RecorderEvent& event)>;

  SurveillanceRecorder();
  ~SurveillanceRecorder();

  SurveillanceRecorder(const SurveillanceRecorder&) = delete;
  SurveillanceRecorder& operator=(const SurveillanceRecorder&) = delete;

  HRESULT Start(const RecorderConfig& config);
  HRESULT Stop();
  HRESULT PauseForPalm();
  HRESULT Resume();
  HRESULT GetRootDir(const std::string& device_id, std::string* utf8_dir);

  void SetEventCallback(EventCallback callback) { event_callback_ = std::move(callback); }

  bool is_recording() const { return recording_; }

  void OnTimer();
  void OnCaptureEvent(GUID type, HRESULT status);
  void PostEngineEvent(UINT kind, HRESULT status);

 private:
  HRESULT EnsureMessageWindow();
  HRESULT PickCamera(std::wstring* symbolic_link);
  HRESULT InitEngine(const std::wstring& symbolic_link);
  HRESULT StartSegment();
  HRESULT StopSegment(bool finalize);
  void ShutdownEngine();
  HRESULT PrepareOutputDir(std::wstring* dir);
  HRESULT CheckStorage(const std::wstring& dir);
  void Emit(const std::string& type);
  void EmitSegmentCompleted(const std::wstring& path);
  void DeleteInProgress();

  HWND hwnd_ = nullptr;
  RecorderConfig config_;
  EventCallback event_callback_;
  bool recording_ = false;
  bool engine_ready_ = false;
  bool want_next_segment_ = false;
  std::wstring output_dir_;
  std::wstring in_progress_path_;
  std::wstring pending_final_path_;

  struct Impl;
  Impl* impl_ = nullptr;
};

}  // namespace skp_surveillance

#endif  // RUNNER_SURVEILLANCE_RECORDER_H_
