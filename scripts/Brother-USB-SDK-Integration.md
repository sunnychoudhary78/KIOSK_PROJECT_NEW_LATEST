# Brother USB Printer Telemetry – Technical Reference

**Purpose:** Document the proven USB communication approach used to retrieve printer information from a Brother HL-L3280CDW series printer. This is a reference for migrating the test into the kiosk's production Windows application.

**Status:** USB communication and the listed query methods were successfully tested from Windows PowerShell 5.1 using Brother AppDevKit. This document records the tested approach; it does not claim that a production C# helper has already been implemented.

## 1. Tested environment

| Item | Tested value |
|---|---|
| Printer | Brother HL-L3280CDW series |
| Serial number | E81700F6N668299 |
| USB vendor ID | `0x04F9` |
| USB product ID | `0x04F5` |
| Firmware MAIN | `1.41` |
| Firmware SUB3 | `M2412091906` |
| Host | Windows PowerShell 5.1, 32-bit |
| SDK directory | `C:\\Program Files (x86)\\Brother\\iPrint&Scan` |
| Assemblies | `BRAppDevKitQuery2.dll`, `BRAppDevKitCommon.dll` |
| Query assembly version | `BRAppDevKitQuery2, Version=0.2.31.0` |

The telemetry test communicated over USB. It did not use SNMP, a printer IP address, or Wi-Fi to retrieve these SDK values.

**Architecture warning:** The successful test used 32-bit Windows PowerShell 5.1. The kiosk Flutter Windows runner is x64. Do not assume the tested DLLs can be loaded into an x64 process. Inspect the actual DLL architecture and confirm whether Brother provides x64 assemblies. If the available SDK is x86-only, run it in a separate x86 helper process and communicate with the x64 kiosk over local IPC. Do not attempt to load an x86 assembly into an x64 process.

## 2. SDK assemblies and types

The tested script loads:
- `BRAppDevKitCommon.dll`
- `BRAppDevKitQuery2.dll`

Shared types in `BRAppDevKitCommon.dll`:
- `Brooklyn.AppDevKit.Common.DeviceInfo`
- `Brooklyn.AppDevKit.Common.DeviceConnectionInfo`
- `Brooklyn.AppDevKit.Common.ConnectionType`
- `Brooklyn.AppDevKit.Common.DeviceCategory`

The query API is provided by `BRAppDevKitQuery2.dll`. The working test uses .NET reflection because PowerShell's normal method binder did not reliably resolve some SDK overloads.

### Assembly-loading pattern

This is the core loading pattern used by the test, assuming the current directory contains the DLLs:

```powershell
$commonAsm = [Reflection.Assembly]::LoadFrom(
    (Resolve-Path ".\\BRAppDevKitCommon.dll").Path
)
$asm = [Reflection.Assembly]::LoadFrom(
    (Resolve-Path ".\\BRAppDevKitQuery2.dll").Path
)
$di = $commonAsm.GetType("Brooklyn.AppDevKit.Common.DeviceInfo")
$connType = $commonAsm.GetType("Brooklyn.AppDevKit.Common.DeviceConnectionInfo")
$enum = $commonAsm.GetType("Brooklyn.AppDevKit.Common.ConnectionType")
$categoryType = $commonAsm.GetType("Brooklyn.AppDevKit.Common.DeviceCategory")
```

USB device creation uses:

```text
USBDeviceCreater.CreateHttpOverUSBDeviceAsync(...)
```

This is the tested USB device-creation path. The SDK uses its HTTP-over-USB mechanism internally; it does not require the kiosk to connect to a printer IP address or use ordinary network HTTP.

**Important:** Take the exact overload and argument construction from the working `Brother-USB-Telemetry.ps1` supplied alongside this document. Do not guess method signatures from this summary.

## 3. How the test was run

The script was placed in the Brother SDK directory and run using 32-bit Windows PowerShell 5.1:

```powershell
cd "C:\\Program Files (x86)\\Brother\\iPrint&Scan"
Set-ExecutionPolicy -Scope Process Bypass
.\\Brother-USB-Telemetry.ps1
```

The script loads the SDK assemblies, creates the USB device with `USBDeviceCreater.CreateHttpOverUSBDeviceAsync(...)`, invokes SDK query methods, and prints the returned information.

PowerShell compatibility findings:
- Use 32-bit Windows PowerShell 5.1 for the tested x86 SDK environment.
- Use reflection to select/invoke SDK methods where overload binding fails.
- Avoid naming a variable `$args` because it is an automatic PowerShell variable.
- `Convert.FromHexString` is unavailable in Windows PowerShell 5.1; use compatible byte conversion such as `Convert.ToByte(...)` when decoding hex.
- Passing `$null` for an optional/nullable cancellation token worked in the tested calls. Preserve the exact invocation from the script rather than assuming every SDK method accepts it.

## 4. SDK query methods successfully exercised

| SDK method | Confirmed result |
|---|---|
| `QueryStatus` | Status code/message/type and supplies information |
| `QueryFirmwareInformation` | Model, serial number and firmware |
| `QueryMachineInfo` | Device identifier and machine information string |
| `QueryPageCountInfo` | Total, colour and B&W page counters |
| `QueryPageFuncType` / `QueryPageFuncCount` | Function-type page counts |
| `QueryNextCareInfo` | Belt and fuser remaining-page information |
| `QueryMaintenceInfo` | Raw maintenance records, including toner values |
| `QueryPaperType` | Paper-size counters |
| `QueryMediaType` | Media-type counters |
| `QueryErrorHistoryPageCount` / `QueryErrorHistoryDescription` | Error-history count and description retrieval |

Known limitations:
- `QueryErrorHistory` itself threw `NotImplementedException`; the separate page-count and description methods worked.
- `BrInfoMaintenance2Parser` returned an empty list in the tested response, so paper-tray levels were not retrieved through that parser.
- `QueryReplaceCountInfo` and `QueryJamsCountInfo` returned raw hexadecimal data whose record meanings were not verified.
- `QueryReplaceCountInfoByte` threw `NotImplementedException` over USB.
- Do not expose unmapped raw record IDs as user-facing metrics until independently verified.

## 5. Verified information and observed values

### 5.1 Printer status

`QueryStatus` returned a status code, message and status type.

| Test moment | Status code | Message | Status type |
|---|---:|---|---|
| Idle / sleep | `40000` | `Sleep` | `Ready` |
| Print startup | `10003` | `Please Wait` | `Ready` |
| During print | `10023` | `Printing` | `Ready` |
| After print | `10001` | `Ready` | `Ready` |

This demonstrates the observed sleep, startup, printing and ready states. Do not assume these are the only possible status codes. Preserve raw code/message in diagnostics so unknown states are not silently misclassified.

### 5.2 Toner

The `QueryStatus` supplies list contained four toner supplies. The maintenance response also contained these toner records:

| Record ID | Toner | Observed level |
|---:|---|---:|
| `129` | Black | 80% |
| `130` | Cyan | 90% |
| `131` | Magenta | 90% |
| `132` | Yellow | 90% |

These percentages were observed in the test output. Preserve raw SDK values and confirm units/range before converting values for other models.

### 5.3 Page counters

`QueryPageCountInfo` worked. Verified record IDs:

| Record ID | Meaning | After one-page colour test |
|---:|---|---:|
| `0` | Total pages | 176 |
| `2` | Colour pages | 159 |
| `1` | B&W pages | 17 |

Before the one-page colour test: total 175, colour 158, B&W 17. After: total 176, colour 159, B&W 17.

This confirms that the SDK total and colour counters increased for that test.

**Critical reconciliation warning:** These `QueryPageCountInfo` values have not been proven equivalent to the SNMP `prtMarkerLifeCount` currently used by kiosk reconciliation. The two sources must be compared over multiple controlled jobs before the USB counter is used to verify kiosk jobs. Do not substitute the SDK total-page value for the SNMP lifetime counter based on this single test.

### 5.4 Page-function counters

`QueryPageFuncType` and `QueryPageFuncCount` worked. Observed post-test values:

| Index | Function type | Count | Established interpretation |
|---:|---:|---:|---|
| 1 | 1 | 171 | Print |
| 2 | 5 | 159 | Colour |
| 3 | 7 | 12 | B&W |
| 7 | 91 | 5 | Unmapped |
| 9 | 92 | 5 | Unmapped |

These are separate from `QueryPageCountInfo`. Do not conflate the two sets. Meanings of type 91 and 92 were not established.

### 5.5 Belt and fuser

`QueryNextCareInfo` worked.

| Record ID | Meaning | Latest observed value |
|---:|---|---:|
| `0x88` | Belt remaining pages | 49,790 |
| `0x73` | Fuser remaining pages | 49,824 |

Earlier readings differed slightly. Treat these as device-reported remaining-page values.

### 5.6 Firmware and machine information

`QueryFirmwareInformation` returned:
- Model: `HL-L3280CDW series`
- Serial: `E81700F6N668299`
- MAIN firmware: `1.41`
- SUB3 firmware: `M2412091906`

`QueryMachineInfo` returned:

```text
BRW145A4114F588,,,E81700F6N668299,1.41,,262144
```

The device identifier and serial/firmware portions were identified. The final `262144` may represent 256 MB in KB, but this interpretation was not conclusively verified. Do not expose it as confirmed memory capacity.

### 5.7 Error history

- `QueryErrorHistory` threw `NotImplementedException`.
- `QueryErrorHistoryPageCount` and `QueryErrorHistoryDescription` worked.
- One observed latest history item was page 19, description `Cannot Print ZC`.
- Full history depth and all description mappings were not established.

### 5.8 Paper and media counters

`QueryPaperType` and `QueryMediaType` worked and returned counters. Latest observed paper-size counters: `176, 0, 0, 0, 0, 0`. Media counters: `176, 0, 0, 0, 0, 0, 0, 0`.

These are historical counters, not current tray paper levels.

## 6. Not yet verified

Keep these explicitly unverified:
- Whether the SDK total page counter equals SNMP `prtMarkerLifeCount`.
- Whether SDK counters increment once per physical sheet for every print mode and job type.
- Whether toner values are always percentages across models and firmware.
- USB equivalents for tray level, complete error history, door-open state and all SNMP error flags.
- Meanings of unknown maintenance, replacement and jam raw record IDs.
- Whether the SDK can maintain/reopen a USB session while the Windows USB printer driver is printing.
- Whether the installed SDK assemblies are x86-only or whether x64 assemblies are available.
- SDK redistribution/licensing requirements.
- Whether methods and values behave identically on other Brother models.

## 7. Recommended production integration

The kiosk Windows runner is C++17 and x64. The SDK test ran from 32-bit PowerShell 5.1. Use a process boundary unless compatible x64 SDK assemblies are confirmed.

Suggested structure:

```text
skp_kiosk.exe (Flutter Windows, x64)
    |
    | existing Flutter method channel: skp/printer
    v
PrinterPlugin (C++)
    |
    | local IPC (named pipe is worth evaluating)
    v
Brother USB helper process (.NET)
    |
    | Brother AppDevKit DLLs
    v
Brother printer over USB
```

The helper should own:
- Loading AppDevKit assemblies.
- Discovering/opening the intended USB printer.
- Invoking the proven SDK query methods.
- Parsing responses into a stable JSON contract.
- SDK resource/device-handle management.
- USB removal detection and reconnection.
- Clear errors and last-success timestamps.
- Preventing old telemetry from being represented as fresh after failed reads.

The C++ plugin should expose helper snapshots to Dart through the existing method channel. Do not put SDK reflection or DLL loading in the Flutter UI.

Evaluate a persistent helper process to avoid starting the .NET runtime and initializing the SDK on every poll. Give it a controlled lifecycle, request/response protocol, timeouts and recovery behavior. Confirm SDK thread-safety and handle rules before allowing concurrent requests.

### Illustrative JSON shape

This is an example contract only; it is not a claim that the SDK returns these exact JSON fields:

```json
{
  "connected": true,
  "readAt": "ISO-8601 timestamp",
  "model": "HL-L3280CDW series",
  "serialNumber": "E81700F6N668299",
  "firmware": {
    "main": "1.41",
    "sub3": "M2412091906"
  },
  "status": {
    "code": 10001,
    "message": "Ready",
    "type": "Ready"
  },
  "toner": {
    "blackPercent": 80,
    "cyanPercent": 90,
    "magentaPercent": 90,
    "yellowPercent": 90
  },
  "pageCounts": {
    "total": 176,
    "color": 159,
    "blackAndWhite": 17
  },
  "maintenance": {
    "beltRemainingPages": 49790,
    "fuserRemainingPages": 49824
  },
  "error": null
}
```

Derive fields from actual SDK responses. Preserve raw values and omit unavailable values rather than fabricating zeroes.

## 8. Phase 2 validation plan

During Phase 2, keep SNMP authoritative for printer health, heartbeat, paper-out pause and print-job reconciliation. Collect USB telemetry alongside SNMP for comparison only.

Run controlled tests:
1. Idle/ready.
2. Sleep, then wake.
3. One-page colour job.
4. One-page B&W job.
5. Multi-page colour job.
6. Multi-page B&W job.
7. Paper-out.
8. Jam, if safely reproducible.
9. USB unplug while idle.
10. USB unplug during or immediately after printing.
11. USB reconnect and recovery.
12. SDK polling while Windows is actively printing.

For each print comparison, record job ID, expected sheets, SNMP baseline/final counter, USB baseline/final counters, timestamps and any concurrent print activity.

Do not switch reconciliation to USB until the correct USB counter has been proven over multiple controlled jobs. Do not remove SNMP until USB status, freshness, disconnect/reconnect and paper-out behavior are validated.

## 9. Files to give Cursor

Provide these together:
1. `Brother-USB-Telemetry.ps1` — the actual working PowerShell script. This is the primary source for exact SDK overloads, parameters, reflection calls and parsing.
2. `Brother-USB-SDK-Integration.md` — this document.
3. Raw console output from the successful USB tests, if available.

**Implementation instruction:** Treat the PowerShell script as the executable reference. Reuse exact working SDK calls and response parsing wherever possible. Do not invent method signatures or infer undocumented record meanings from this document. If a detail is absent or ambiguous, inspect the script and SDK metadata or report it as unresolved before implementation.
