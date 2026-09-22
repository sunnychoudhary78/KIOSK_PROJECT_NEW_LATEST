#include "surveillance_recorder.h"

#include <mfapi.h>
#include <mfcaptureengine.h>
#include <mfidl.h>
#include <mferror.h>
#include <objbase.h>
#include <shlobj.h>
#include <wrl/client.h>

#include <algorithm>
#include <cwctype>
#include <vector>

namespace skp_surveillance {

using Microsoft::WRL::ComPtr;

namespace {

constexpr UINT kSegmentTimerId = 1;
constexpr UINT WM_CAPTURE_EVENT = WM_APP + 40;

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return {};
  }
  int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (len <= 1) {
    return {};
  }
  std::wstring out(static_cast<size_t>(len - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, out.data(), len);
  return out;
}

std::string Utf8FromUtf16(const std::wstring& utf16) {
  if (utf16.empty()) {
    return {};
  }
  int len = WideCharToMultiByte(CP_UTF8, 0, utf16.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (len <= 1) {
    return {};
  }
  std::string out(static_cast<size_t>(len - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, utf16.c_str(), -1, out.data(), len, nullptr, nullptr);
  return out;
}

bool EndsWithInProgress(const std::wstring& path) {
  const std::wstring marker = L".inprogress.mp4";
  if (path.size() < marker.size()) {
    return false;
  }
  return _wcsicmp(path.c_str() + (path.size() - marker.size()), marker.c_str()) == 0;
}

int64_t FileSizeBytes(const std::wstring& path) {
  WIN32_FILE_ATTRIBUTE_DATA info = {};
  if (!GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &info)) {
    return 0;
  }
  LARGE_INTEGER size;
  size.HighPart = static_cast<LONG>(info.nFileSizeHigh);
  size.LowPart = info.nFileSizeLow;
  return size.QuadPart;
}

bool EnsureDir(const std::wstring& path);

HRESULT DeviceSurveillanceRoot(const std::string& device_id, std::wstring* root) {
  if (device_id.empty() || !root) {
    return E_INVALIDARG;
  }
  PWSTR program_data = nullptr;
  HRESULT hr = SHGetKnownFolderPath(FOLDERID_ProgramData, KF_FLAG_CREATE, nullptr, &program_data);
  if (FAILED(hr)) {
    return hr;
  }
  *root = std::wstring(program_data) + L"\\SmartKiosk\\surveillance\\" + Utf16FromUtf8(device_id);
  CoTaskMemFree(program_data);
  if (!EnsureDir(*root)) {
    return E_FAIL;
  }
  return S_OK;
}

std::wstring ToLower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(), [](wchar_t c) {
    return static_cast<wchar_t>(towlower(c));
  });
  return value;
}

int NameScore(const std::wstring& name) {
  const std::wstring n = ToLower(name);
  int score = 0;
  if (n.find(L"usb") != std::wstring::npos) {
    score += 4;
  }
  if (n.find(L"uvc") != std::wstring::npos) {
    score += 4;
  }
  if (n.find(L"external") != std::wstring::npos) {
    score += 3;
  }
  if (n.find(L"capture") != std::wstring::npos) {
    score += 2;
  }
  if (n.find(L"rgb-ir") != std::wstring::npos || n.find(L"rgbir") != std::wstring::npos ||
      n.find(L"rgb ir") != std::wstring::npos) {
    score -= 5;
  }
  if (n.find(L"infrared") != std::wstring::npos) {
    score -= 4;
  }
  if (n == L"ir" || n.find(L"ir ") != std::wstring::npos || n.find(L" ir") != std::wstring::npos) {
    score -= 4;
  }
  if (n.find(L"hello") != std::wstring::npos) {
    score -= 3;
  }
  if (n.find(L"integrated") != std::wstring::npos) {
    score -= 2;
  }
  return score;
}

bool EnsureDir(const std::wstring& path) {
  if (path.empty()) {
    return false;
  }
  if (CreateDirectoryW(path.c_str(), nullptr) || GetLastError() == ERROR_ALREADY_EXISTS) {
    return true;
  }
  const auto slash = path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return false;
  }
  if (!EnsureDir(path.substr(0, slash))) {
    return false;
  }
  return CreateDirectoryW(path.c_str(), nullptr) || GetLastError() == ERROR_ALREADY_EXISTS;
}

int64_t DirSize(const std::wstring& path) {
  int64_t total = 0;
  const std::wstring query = path + L"\\*";
  WIN32_FIND_DATAW data;
  HANDLE find = FindFirstFileW(query.c_str(), &data);
  if (find == INVALID_HANDLE_VALUE) {
    return 0;
  }
  do {
    const std::wstring name = data.cFileName;
    if (name == L"." || name == L"..") {
      continue;
    }
    const std::wstring child = path + L"\\" + name;
    if (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
      total += DirSize(child);
    } else {
      LARGE_INTEGER size;
      size.HighPart = data.nFileSizeHigh;
      size.LowPart = data.nFileSizeLow;
      total += size.QuadPart;
    }
  } while (FindNextFileW(find, &data));
  FindClose(find);
  return total;
}

std::wstring NewGuid() {
  GUID guid;
  CoCreateGuid(&guid);
  wchar_t buf[64];
  StringFromGUID2(guid, buf, 64);
  std::wstring value = buf;
  value.erase(std::remove(value.begin(), value.end(), L'{'), value.end());
  value.erase(std::remove(value.begin(), value.end(), L'}'), value.end());
  value.erase(std::remove(value.begin(), value.end(), L'-'), value.end());
  return value.substr(0, 12);
}

HRESULT CopyAsH264(IMFMediaType* src, IMFMediaType** dest, UINT32 fps, UINT32 bitrate) {
  ComPtr<IMFMediaType> typed;
  HRESULT hr = MFCreateMediaType(&typed);
  if (FAILED(hr)) {
    return hr;
  }
  hr = src->CopyAllItems(typed.Get());
  if (FAILED(hr)) {
    return hr;
  }
  hr = typed->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
  if (FAILED(hr)) {
    return hr;
  }
  if (fps > 0) {
    MFSetAttributeRatio(typed.Get(), MF_MT_FRAME_RATE, fps, 1);
  }
  if (bitrate > 0) {
    typed->SetUINT32(MF_MT_AVG_BITRATE, bitrate);
  }
  *dest = typed.Detach();
  return S_OK;
}

}  // namespace

struct SurveillanceRecorder::Impl {
  ComPtr<IMFMediaSource> video_source;
  ComPtr<IMFCaptureEngine> engine;
  ComPtr<IMFCaptureRecordSink> record_sink;
  ComPtr<IMFMediaType> base_type;
  ComPtr<IMFCaptureEngineOnEventCallback> callback;
};

class EngineCallback : public IMFCaptureEngineOnEventCallback {
 public:
  explicit EngineCallback(SurveillanceRecorder* recorder) : recorder_(recorder) {}

  STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (!ppv) {
      return E_POINTER;
    }
    *ppv = nullptr;
    if (riid == IID_IUnknown || riid == IID_IMFCaptureEngineOnEventCallback) {
      *ppv = static_cast<IMFCaptureEngineOnEventCallback*>(this);
      AddRef();
      return S_OK;
    }
    return E_NOINTERFACE;
  }

  STDMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&ref_); }

  STDMETHODIMP_(ULONG) Release() override {
    const LONG ref = InterlockedDecrement(&ref_);
    if (ref == 0) {
      delete this;
    }
    return static_cast<ULONG>(ref);
  }

  STDMETHODIMP OnEvent(IMFMediaEvent* event) override {
    if (!event || !recorder_) {
      return S_OK;
    }
    GUID type = GUID_NULL;
    event->GetExtendedType(&type);
    HRESULT status = S_OK;
    event->GetStatus(&status);
    UINT kind = 0;
    if (type == MF_CAPTURE_ENGINE_INITIALIZED) {
      kind = 1;
    } else if (type == MF_CAPTURE_ENGINE_RECORD_STARTED) {
      kind = 2;
    } else if (type == MF_CAPTURE_ENGINE_RECORD_STOPPED) {
      kind = 3;
    } else if (type == MF_CAPTURE_ENGINE_ERROR) {
      kind = 4;
    } else {
      return S_OK;
    }
    recorder_->PostEngineEvent(kind, status);
    return S_OK;
  }

 private:
  SurveillanceRecorder* recorder_;
  LONG ref_ = 1;
};

LRESULT CALLBACK RecorderWndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
  auto* recorder = reinterpret_cast<SurveillanceRecorder*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (msg == WM_NCCREATE) {
    auto* cs = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(cs->lpCreateParams));
    return TRUE;
  }
  if (!recorder) {
    return DefWindowProc(hwnd, msg, wparam, lparam);
  }
  if (msg == WM_TIMER && wparam == kSegmentTimerId) {
    recorder->OnTimer();
    return 0;
  }
  if (msg == WM_CAPTURE_EVENT) {
    GUID type = GUID_NULL;
    if (wparam == 1) {
      type = MF_CAPTURE_ENGINE_INITIALIZED;
    } else if (wparam == 2) {
      type = MF_CAPTURE_ENGINE_RECORD_STARTED;
    } else if (wparam == 3) {
      type = MF_CAPTURE_ENGINE_RECORD_STOPPED;
    } else if (wparam == 4) {
      type = MF_CAPTURE_ENGINE_ERROR;
    }
    recorder->OnCaptureEvent(type, static_cast<HRESULT>(lparam));
    return 0;
  }
  return DefWindowProc(hwnd, msg, wparam, lparam);
}

SurveillanceRecorder::SurveillanceRecorder() : impl_(new Impl()) {}

SurveillanceRecorder::~SurveillanceRecorder() {
  Stop();
  if (hwnd_) {
    DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
  delete impl_;
  impl_ = nullptr;
}

HRESULT SurveillanceRecorder::EnsureMessageWindow() {
  if (hwnd_) {
    return S_OK;
  }
  WNDCLASSW wc = {};
  wc.lpfnWndProc = RecorderWndProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.lpszClassName = L"SkpSurveillanceRecorder";
  RegisterClassW(&wc);
  hwnd_ = CreateWindowExW(0, wc.lpszClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr,
                          wc.hInstance, this);
  return hwnd_ ? S_OK : E_FAIL;
}

void SurveillanceRecorder::PostEngineEvent(UINT kind, HRESULT status) {
  if (hwnd_) {
    PostMessageW(hwnd_, WM_CAPTURE_EVENT, kind, static_cast<LPARAM>(status));
  }
}

void SurveillanceRecorder::Emit(const std::string& type) {
  if (event_callback_) {
    RecorderEvent event;
    event.type = type;
    event_callback_(event);
  }
}

void SurveillanceRecorder::EmitSegmentCompleted(const std::wstring& path) {
  if (path.empty() || EndsWithInProgress(path) || !event_callback_) {
    return;
  }
  RecorderEvent event;
  event.type = "SEGMENT_COMPLETED";
  event.path = Utf8FromUtf16(path);
  event.bytes = FileSizeBytes(path);
  event_callback_(event);
}

HRESULT SurveillanceRecorder::GetRootDir(const std::string& device_id, std::string* utf8_dir) {
  if (!utf8_dir) {
    return E_POINTER;
  }
  std::wstring root;
  HRESULT hr = DeviceSurveillanceRoot(device_id, &root);
  if (FAILED(hr)) {
    return hr;
  }
  *utf8_dir = Utf8FromUtf16(root);
  return S_OK;
}

HRESULT SurveillanceRecorder::Start(const RecorderConfig& config) {
  if (recording_) {
    return S_OK;
  }
  MFStartup(MF_VERSION);
  config_ = config;
  HRESULT hr = EnsureMessageWindow();
  if (FAILED(hr)) {
    return hr;
  }
  std::wstring link;
  hr = PickCamera(&link);
  if (FAILED(hr)) {
    Emit("CAMERA_ERROR");
    return hr;
  }
  hr = PrepareOutputDir(&output_dir_);
  if (FAILED(hr)) {
    Emit("STORAGE_LOW");
    return hr;
  }
  hr = CheckStorage(output_dir_);
  if (FAILED(hr)) {
    Emit("STORAGE_LOW");
    return hr;
  }
  DeleteInProgress();
  hr = InitEngine(link);
  if (FAILED(hr)) {
    Emit("CAMERA_ERROR");
    return hr;
  }
  want_next_segment_ = true;
  return S_OK;
}

HRESULT SurveillanceRecorder::Resume() { return Start(config_); }

HRESULT SurveillanceRecorder::PauseForPalm() {
  want_next_segment_ = false;
  KillTimer(hwnd_, kSegmentTimerId);
  HRESULT hr = StopSegment(true);
  ShutdownEngine();
  recording_ = false;
  return hr;
}

HRESULT SurveillanceRecorder::Stop() {
  want_next_segment_ = false;
  if (hwnd_) {
    KillTimer(hwnd_, kSegmentTimerId);
  }
  HRESULT hr = StopSegment(true);
  ShutdownEngine();
  recording_ = false;
  return hr;
}

void SurveillanceRecorder::OnTimer() {
  want_next_segment_ = true;
  StopSegment(true);
}

void SurveillanceRecorder::OnCaptureEvent(GUID type, HRESULT status) {
  if (FAILED(status) && type == MF_CAPTURE_ENGINE_ERROR) {
    recording_ = false;
    want_next_segment_ = false;
    KillTimer(hwnd_, kSegmentTimerId);
    ShutdownEngine();
    Emit("CAMERA_ERROR");
    return;
  }
  if (type == MF_CAPTURE_ENGINE_INITIALIZED) {
    engine_ready_ = SUCCEEDED(status);
    if (engine_ready_ && want_next_segment_) {
      if (FAILED(StartSegment())) {
        Emit("CAMERA_ERROR");
      }
    }
    return;
  }
  if (type == MF_CAPTURE_ENGINE_RECORD_STARTED) {
    recording_ = true;
    const UINT ms = static_cast<UINT>(std::max(1, config_.segment_seconds) * 1000);
    SetTimer(hwnd_, kSegmentTimerId, ms, nullptr);
    return;
  }
  if (type == MF_CAPTURE_ENGINE_RECORD_STOPPED) {
    recording_ = false;
    if (!in_progress_path_.empty() && !pending_final_path_.empty() &&
        !EndsWithInProgress(pending_final_path_)) {
      if (MoveFileExW(in_progress_path_.c_str(), pending_final_path_.c_str(),
                      MOVEFILE_REPLACE_EXISTING)) {
        EmitSegmentCompleted(pending_final_path_);
      }
    }
    in_progress_path_.clear();
    pending_final_path_.clear();
    if (want_next_segment_ && engine_ready_) {
      if (FAILED(CheckStorage(output_dir_))) {
        want_next_segment_ = false;
        Emit("STORAGE_LOW");
        ShutdownEngine();
        return;
      }
      StartSegment();
    }
  }
}

HRESULT SurveillanceRecorder::PickCamera(std::wstring* symbolic_link) {
  ComPtr<IMFAttributes> attrs;
  HRESULT hr = MFCreateAttributes(&attrs, 1);
  if (FAILED(hr)) {
    return hr;
  }
  hr = attrs->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                      MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
  if (FAILED(hr)) {
    return hr;
  }
  IMFActivate** devices = nullptr;
  UINT32 count = 0;
  hr = MFEnumDeviceSources(attrs.Get(), &devices, &count);
  if (FAILED(hr) || count == 0) {
    return FAILED(hr) ? hr : E_FAIL;
  }
  int best_score = -0x7fffffff;
  UINT32 best_index = 0;
  for (UINT32 i = 0; i < count; i++) {
    WCHAR* name = nullptr;
    UINT32 name_len = 0;
    if (SUCCEEDED(devices[i]->GetAllocatedString(MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME, &name,
                                                 &name_len))) {
      const int score = NameScore(name);
      if (score > best_score) {
        best_score = score;
        best_index = i;
      }
      CoTaskMemFree(name);
    }
  }
  WCHAR* link = nullptr;
  UINT32 link_len = 0;
  hr = devices[best_index]->GetAllocatedString(
      MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK, &link, &link_len);
  if (SUCCEEDED(hr) && link) {
    *symbolic_link = link;
    CoTaskMemFree(link);
  }
  for (UINT32 i = 0; i < count; i++) {
    devices[i]->Release();
  }
  CoTaskMemFree(devices);
  return hr;
}

HRESULT SurveillanceRecorder::InitEngine(const std::wstring& symbolic_link) {
  ShutdownEngine();
  impl_->callback.Attach(new EngineCallback(this));

  ComPtr<IMFAttributes> source_attrs;
  HRESULT hr = MFCreateAttributes(&source_attrs, 2);
  if (FAILED(hr)) {
    return hr;
  }
  hr = source_attrs->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                             MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
  if (FAILED(hr)) {
    return hr;
  }
  hr = source_attrs->SetString(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK,
                               symbolic_link.c_str());
  if (FAILED(hr)) {
    return hr;
  }
  hr = MFCreateDeviceSource(source_attrs.Get(), impl_->video_source.ReleaseAndGetAddressOf());
  if (FAILED(hr)) {
    return hr;
  }

  ComPtr<IMFCaptureEngineClassFactory> factory;
  hr = CoCreateInstance(CLSID_MFCaptureEngineClassFactory, nullptr, CLSCTX_INPROC_SERVER,
                        IID_PPV_ARGS(&factory));
  if (FAILED(hr)) {
    return hr;
  }
  hr = factory->CreateInstance(CLSID_MFCaptureEngine, IID_PPV_ARGS(&impl_->engine));
  if (FAILED(hr)) {
    return hr;
  }

  ComPtr<IMFAttributes> engine_attrs;
  hr = MFCreateAttributes(&engine_attrs, 1);
  if (FAILED(hr)) {
    return hr;
  }
  engine_attrs->SetUINT32(MF_CAPTURE_ENGINE_USE_VIDEO_DEVICE_ONLY, TRUE);
  engine_ready_ = false;
  return impl_->engine->Initialize(impl_->callback.Get(), engine_attrs.Get(), nullptr,
                                   impl_->video_source.Get());
}

HRESULT SurveillanceRecorder::StartSegment() {
  if (!impl_->engine) {
    return E_FAIL;
  }
  SYSTEMTIME utc;
  GetSystemTime(&utc);
  wchar_t stamp[16];
  swprintf_s(stamp, L"%02u%02u%02u", utc.wHour, utc.wMinute, utc.wSecond);
  pending_final_path_ = output_dir_ + L"\\" + stamp + L"_" + NewGuid() + L".mp4";
  in_progress_path_ = output_dir_ + L"\\.inprogress.mp4";
  DeleteFileW(in_progress_path_.c_str());

  ComPtr<IMFCaptureSink> sink;
  HRESULT hr = impl_->engine->GetSink(MF_CAPTURE_ENGINE_SINK_TYPE_RECORD, &sink);
  if (FAILED(hr)) {
    return hr;
  }
  hr = sink.As(&impl_->record_sink);
  if (FAILED(hr)) {
    return hr;
  }
  impl_->record_sink->RemoveAllStreams();

  ComPtr<IMFCaptureSource> source;
  hr = impl_->engine->GetSource(&source);
  if (FAILED(hr)) {
    return hr;
  }
  ComPtr<IMFMediaType> native_type;
  hr = source->GetAvailableDeviceMediaType(
      static_cast<DWORD>(MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_VIDEO_RECORD), 0,
      &native_type);
  if (FAILED(hr)) {
    return hr;
  }
  ComPtr<IMFMediaType> h264;
  hr = CopyAsH264(native_type.Get(), &h264, static_cast<UINT32>(config_.fps),
                  static_cast<UINT32>(config_.bitrate));
  if (FAILED(hr)) {
    return hr;
  }
  if (config_.width > 0 && config_.height > 0) {
    MFSetAttributeSize(h264.Get(), MF_MT_FRAME_SIZE, static_cast<UINT32>(config_.width),
                       static_cast<UINT32>(config_.height));
  }
  DWORD stream_index = 0;
  hr = impl_->record_sink->AddStream(
      static_cast<DWORD>(MF_CAPTURE_ENGINE_PREFERRED_SOURCE_STREAM_FOR_VIDEO_RECORD), h264.Get(),
      nullptr, &stream_index);
  if (FAILED(hr)) {
    return hr;
  }
  hr = impl_->record_sink->SetOutputFileName(in_progress_path_.c_str());
  if (FAILED(hr)) {
    return hr;
  }
  return impl_->engine->StartRecord();
}

HRESULT SurveillanceRecorder::StopSegment(bool finalize) {
  if (!impl_->engine || !recording_) {
    if (!finalize) {
      DeleteInProgress();
    }
    return S_OK;
  }
  return impl_->engine->StopRecord(true, false);
}

void SurveillanceRecorder::ShutdownEngine() {
  engine_ready_ = false;
  impl_->record_sink.Reset();
  impl_->engine.Reset();
  impl_->video_source.Reset();
  impl_->callback.Reset();
  impl_->base_type.Reset();
}

HRESULT SurveillanceRecorder::PrepareOutputDir(std::wstring* dir) {
  std::wstring device_root;
  HRESULT hr = DeviceSurveillanceRoot(config_.device_id, &device_root);
  if (FAILED(hr)) {
    return hr;
  }
  SYSTEMTIME utc;
  GetSystemTime(&utc);
  wchar_t day[16];
  swprintf_s(day, L"%04u-%02u-%02u", utc.wYear, utc.wMonth, utc.wDay);
  std::wstring root = device_root + L"\\" + day;
  if (!EnsureDir(root)) {
    return E_FAIL;
  }
  *dir = root;
  return S_OK;
}

HRESULT SurveillanceRecorder::CheckStorage(const std::wstring& dir) {
  ULARGE_INTEGER free_bytes;
  if (!GetDiskFreeSpaceExW(dir.c_str(), &free_bytes, nullptr, nullptr)) {
    return E_FAIL;
  }
  if (free_bytes.QuadPart < 1024ull * 1024ull * 1024ull) {
    return HRESULT_FROM_WIN32(ERROR_DISK_FULL);
  }
  const auto slash = dir.find_last_of(L"\\/");
  std::wstring device_root = slash == std::wstring::npos ? dir : dir.substr(0, slash);
  const auto slash2 = device_root.find_last_of(L"\\/");
  if (slash2 != std::wstring::npos) {
    device_root = device_root.substr(0, slash2);
  }
  if (DirSize(device_root) >= config_.max_cache_bytes) {
    return HRESULT_FROM_WIN32(ERROR_DISK_FULL);
  }
  return S_OK;
}

void SurveillanceRecorder::DeleteInProgress() {
  if (!output_dir_.empty()) {
    const std::wstring leftover = output_dir_ + L"\\.inprogress.mp4";
    DeleteFileW(leftover.c_str());
  }
}

}  // namespace skp_surveillance
