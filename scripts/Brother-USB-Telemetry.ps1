# Brother HL-L3280CDW USB Telemetry Collector
# Run with 32-bit Windows PowerShell 5.1 (x86).
# Keep this script in the Brother iPrint&Scan installation folder.

$ErrorActionPreference = "Stop"

function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 68) -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host ("=" * 68) -ForegroundColor DarkCyan
}

function Invoke-SdkMethod([object]$Target, [string]$Name, [object[]]$Arguments = @()) {
    $methods = @($Target.GetType().GetMethods() | Where-Object {
        $_.Name -eq $Name -and $_.GetParameters().Count -eq $Arguments.Count
    })
    if ($methods.Count -eq 0) { throw "SDK method '$Name' with $($Arguments.Count) parameter(s) was not found." }
    $method = $methods[0]
    $invokeArgs = New-Object object[] $Arguments.Count
    for ($i = 0; $i -lt $Arguments.Count; $i++) { $invokeArgs[$i] = $Arguments[$i] }
    $task = $method.Invoke($Target, $invokeArgs)
    if ($task -is [System.Threading.Tasks.Task]) {
        $task.Wait()
        if ($task.IsFaulted) { throw $task.Exception.GetBaseException() }
        $resultProperty = $task.GetType().GetProperty("Result")
        if ($resultProperty) { return $resultProperty.GetValue($task, $null) }
        return $null
    }
    return $task
}

function Convert-HexToBytes([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return ,([byte[]]@()) }
    $hex = ($Value -replace '^0x', '') -replace '[^0-9a-fA-F]', ''
    if (($hex.Length % 2) -ne 0) { throw "Invalid hex response: odd number of hex characters." }
    $bytes = New-Object byte[] ($hex.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16)
    }
    return ,$bytes
}

function Convert-Records([byte[]]$Bytes) {
    # Observed Brother record format: ID, 01, 04, 4-byte big-endian value; FF terminates.
    $records = @()
    for ($i = 0; $i + 6 -lt $Bytes.Length; ) {
        if ($Bytes[$i] -eq 0xFF) { break }
        if ($Bytes[$i + 1] -eq 0x01 -and $Bytes[$i + 2] -eq 0x04) {
            $value = ([uint32]$Bytes[$i + 3] * 16777216) +
                     ([uint32]$Bytes[$i + 4] * 65536) +
                     ([uint32]$Bytes[$i + 5] * 256) +
                     [uint32]$Bytes[$i + 6]
            $records += [pscustomobject]@{
                Id = [int]$Bytes[$i]
                HexId = ('0x{0:X2}' -f $Bytes[$i])
                Value = [uint32]$value
            }
            $i += 7
        } else { break }
    }
    return $records
}

function Show-RawAndRecords([string]$Title, [string]$Raw) {
    Write-Section $Title
    if ([string]::IsNullOrWhiteSpace($Raw)) { Write-Host "No data returned."; return }
    Write-Host "Raw: $Raw"
    try {
        $records = @(Convert-Records (Convert-HexToBytes $Raw))
        if ($records.Count -gt 0) {
            Write-Host "Decoded numeric records (IDs intentionally left unmapped):"
            $records | Format-Table -AutoSize | Out-Host
        }
    } catch { Write-Warning ("Record decoding skipped: " + $_.Exception.Message) }
}

try {
    $sdkDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $queryDll = Join-Path $sdkDir "BRAppDevKitQuery2.dll"
    $commonDll = Join-Path $sdkDir "BRAppDevKitCommon.dll"
    if (-not (Test-Path $queryDll) -or -not (Test-Path $commonDll)) {
        throw "Place this script beside BRAppDevKitQuery2.dll and BRAppDevKitCommon.dll. Expected folder: $sdkDir"
    }
    if ([IntPtr]::Size -ne 4) {
        throw "Run this script in 32-bit Windows PowerShell 5.1 (x86)."
    }

    $commonAsm = [Reflection.Assembly]::LoadFrom($commonDll)
    $asm = [Reflection.Assembly]::LoadFrom($queryDll)

    # These shared device types live in BRAppDevKitCommon.dll, not Query2.dll.
    $di = $commonAsm.GetType("Brooklyn.AppDevKit.Common.DeviceInfo")
    $connType = $commonAsm.GetType("Brooklyn.AppDevKit.Common.DeviceConnectionInfo")
    $connectionEnum = $commonAsm.GetType("Brooklyn.AppDevKit.Common.ConnectionType")
    $categoryType = $commonAsm.GetType("Brooklyn.AppDevKit.Common.DeviceCategory")

    if (-not $di -or -not $connType -or -not $connectionEnum -or -not $categoryType) {
        throw "Could not resolve Brother shared device types from BRAppDevKitCommon.dll."
    }

    $deviceInfo = [Activator]::CreateInstance($di)
    $conn = [Activator]::CreateInstance($connType)
    $conn.Interface = [Enum]::Parse($connectionEnum, "USB")
    $conn.VendorID = 0x04F9
    $conn.ProductID = 0x04F5
    $conn.Location = "USB"
    $deviceInfo.ConnectionInfo = $conn
    $deviceInfo.ModelName = "HL-L3280CDW series"
    $deviceInfo.VendorName = "Brother"
    $deviceInfo.Category = [Enum]::Parse($categoryType, "LaserOrLED")

    $helper = $asm.GetType("Brooklyn.AppDevKit.Query2.LibraryInterface.SDK.SdkDeviceInformation.DiscoveryDeviceHelper")
    $queryDevice = $helper.GetMethod("ToQuerySdkDeviceInformation").Invoke($null, [object[]]@($deviceInfo))

    $factory = $asm.GetType("Brooklyn.AppDevKit.Query2.Device.USB.USBDeviceCreater")
    $createMethod = $factory.GetMethod("CreateHttpOverUSBDeviceAsync")
    $createArgs = New-Object object[] 5
    $createArgs[0] = $deviceInfo
    $createArgs[1] = [Globalization.CultureInfo]::GetCultureInfo("en-US")
    $createArgs[2] = [TimeSpan]::FromSeconds(15)
    $createArgs[3] = [Threading.CancellationToken]::None
    $createArgs[4] = $false
    $createTask = $createMethod.Invoke($null, $createArgs)
    $createTask.Wait()
    if ($createTask.IsFaulted) { throw $createTask.Exception.GetBaseException() }
    $device = $createTask.Result
    if ($null -eq $device) { throw "Brother USB device could not be opened." }

    Write-Section "BROTHER USB PRINTER"
    Write-Host "Connection: USB / Brother HTTP-over-USB bridge"
    Write-Host "Target: HL-L3280CDW series"

    try {
        $status = Invoke-SdkMethod $device "QueryStatus" @([Threading.CancellationToken]::None)
        Write-Section "STATUS AND TONER"
        foreach ($propertyName in @("StatusCode", "StatusMessage", "StatusType", "MethodType", "AdditionalMessage")) {
            $p = $status.GetType().GetProperty($propertyName)
            if ($p) { Write-Host ("{0}: {1}" -f $propertyName, $p.GetValue($status, $null)) }
        }
        $suppliesProperty = $status.GetType().GetProperty("Supplies")
        if ($suppliesProperty) {
            foreach ($supply in $suppliesProperty.GetValue($status, $null)) {
                $st = $supply.GetType()
                $detailP = $st.GetProperty("DetailedType")
                $currentP = $st.GetProperty("CurrentNum")
                $maxP = $st.GetProperty("MaxNum")
                if ($detailP -and $currentP -and $maxP) {
                    $detail = $detailP.GetValue($supply, $null)
                    $current = $currentP.GetValue($supply, $null)
                    $maximum = $maxP.GetValue($supply, $null)
                    if ($maximum -gt 0) {
                        $percent = [math]::Round(($current / $maximum) * 100)
                        Write-Host ("{0}: {1}% (current {2}, max {3})" -f $detail, $percent, $current, $maximum)
                    }
                }
            }
        }
    } catch { Write-Warning ("Status query failed: " + $_.Exception.GetBaseException().Message) }

    foreach ($q in @(
        @{ Name = "QueryFirmwareInformation"; Label = "FIRMWARE INFORMATION" },
        @{ Name = "QueryMachineInfo"; Label = "MACHINE INFORMATION" }
    )) {
        try {
            $v = Invoke-SdkMethod $device $q.Name @([Threading.CancellationToken]::None)
            Write-Section $q.Label
            if ($v -is [string]) { Write-Host $v } else { $v | Format-List * | Out-Host }
        } catch { Write-Warning ($q.Name + ": " + $_.Exception.GetBaseException().Message) }
    }

    try {
        $v = Invoke-SdkMethod $device "QueryPageCountInfo" @($null)
        Show-RawAndRecords "TOTAL / COLOUR / B&W PAGE COUNTERS" ([string]$v)
        $pageRecords = @(Convert-Records (Convert-HexToBytes ([string]$v)))
        foreach ($r in $pageRecords) {
            $label = switch ($r.Id) {
                0 { "Total pages (verified)" }
                2 { "Colour pages (verified)" }
                1 { "Black & white pages (verified)" }
                default { "Unmapped page counter" }
            }
            Write-Host ("{0}: {1}" -f $label, $r.Value)
        }
    } catch { Write-Warning ("QueryPageCountInfo: " + $_.Exception.GetBaseException().Message) }

    Write-Section "PAGE FUNCTION COUNTERS"
    $known = @{ 1 = "Print"; 2 = "Colour"; 3 = "Black & White" }
    for ($i = 0; $i -le 20; $i++) {
        try {
            $typeValue = Invoke-SdkMethod $device "QueryPageFuncType" @([uint32]$i, $null)
            $countValue = Invoke-SdkMethod $device "QueryPageFuncCount" @([uint32]$i, $null)
            if ([uint32]$typeValue -ne 0 -or [uint32]$countValue -ne 0) {
                $label = if ($known.ContainsKey($i)) { $known[$i] } else { "Unmapped function" }
                Write-Host ("Index {0} | Type {1} | Count {2} | {3}" -f $i, $typeValue, $countValue, $label)
            }
        } catch { Write-Warning ("Page function index {0}: {1}" -f $i, $_.Exception.GetBaseException().Message) }
    }

    try {
        $v = Invoke-SdkMethod $device "QueryNextCareInfo" @($null)
        Write-Section "BELT / FUSER AND OTHER NEXT-CARE RECORDS"
        Write-Host "Raw: $v"
        foreach ($r in @(Convert-Records (Convert-HexToBytes ([string]$v)))) {
            $label = switch ($r.Id) {
                136 { "Belt remaining pages (verified mapping)" }
                115 { "Fuser remaining pages (verified mapping)" }
                default { "Unmapped next-care record" }
            }
            Write-Host ("{0}: {1}" -f $label, $r.Value)
        }
    } catch { Write-Warning ("QueryNextCareInfo: " + $_.Exception.GetBaseException().Message) }

    Write-Section "ERROR HISTORY"
    for ($i = 0; $i -le 10; $i++) {
        try {
            $page = Invoke-SdkMethod $device "QueryErrorHistoryPageCount" @([uint32]$i, $null)
            $desc = Invoke-SdkMethod $device "QueryErrorHistoryDescription" @([uint32]$i, $null)
            if (-not [string]::IsNullOrWhiteSpace([string]$desc) -or [uint32]$page -ne 0) {
                Write-Host ("Index {0} | Page {1} | {2}" -f $i, $page, $desc)
            }
        } catch { Write-Warning ("Error history index {0}: {1}" -f $i, $_.Exception.GetBaseException().Message) }
    }

    foreach ($q in @(
        @{ Name = "QueryMaintenceInfo"; Label = "MAINTENANCE INFO (RAW / PARTIALLY DECODED)" },
        @{ Name = "QueryReplaceCountInfo"; Label = "REPLACEMENT COUNTS (RAW / NOT FULLY DECODED)" },
        @{ Name = "QueryJamsCountInfo"; Label = "PAPER JAM COUNTS (RAW / NOT DECODED)" }
    )) {
        try {
            $v = Invoke-SdkMethod $device $q.Name @($null)
            Show-RawAndRecords $q.Label ([string]$v)
        } catch { Write-Warning ($q.Name + ": " + $_.Exception.GetBaseException().Message) }
    }

    foreach ($q in @(
        @{ Name = "QueryPaperType"; Label = "PAPER-SIZE HISTORY" },
        @{ Name = "QueryMediaType"; Label = "MEDIA-TYPE HISTORY" }
    )) {
        try {
            $v = Invoke-SdkMethod $device $q.Name @($null)
            Write-Section $q.Label
            Write-Host "Raw counters: $v"
        } catch { Write-Warning ($q.Name + ": " + $_.Exception.GetBaseException().Message) }
    }

    Write-Section "COLLECTION COMPLETE"
    Write-Host "USB queries only. Unknown record IDs are intentionally not assigned guessed meanings."
}
catch {
    Write-Host ""
    Write-Host ("FATAL: " + $_.Exception.GetBaseException().Message) -ForegroundColor Red
    Write-Host "Check USB connection, Brother software/DLLs, and use 32-bit Windows PowerShell 5.1."
    exit 1
}
