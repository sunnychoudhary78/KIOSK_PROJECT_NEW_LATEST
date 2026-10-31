using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;

namespace SkpPrinterUsb
{
    /// <summary>
    /// Brother AppDevKit calls copied from scripts/Brother-USB-Telemetry.ps1.
    /// DLLs stay in the iPrint&amp;Scan install folder.
    /// </summary>
    sealed class UsbSession
    {
        const int FastCallMs = 5000;
        const int OpenWaitMs = 20000;

        object _device;
        string _firmwareMain;
        string _firmwareSub3;
        string _model;
        string _serial;
        bool _firmwareRead;

        public Snapshot Capture(bool full)
        {
            try
            {
                EnsureDevice();
                var snapshot = new Snapshot { Ok = true, Connected = true };
                ReadStatus(snapshot);
                ReadPageCounts(snapshot);
                if (full)
                {
                    ReadNextCare(snapshot);
                    ReadMaintenance(snapshot);
                    ReadFirmwareOnce(snapshot);
                    ReadErrorHistory(snapshot);
                }
                else
                {
                    snapshot.FirmwareMain = _firmwareMain;
                    snapshot.FirmwareSub3 = _firmwareSub3;
                    snapshot.Model = _model;
                    snapshot.SerialNumber = _serial;
                }
                return snapshot;
            }
            catch (Exception ex)
            {
                DropDevice();
                return Snapshot.Fail(OneLine(ex));
            }
        }

        void EnsureDevice()
        {
            if (_device != null) return;
            if (IntPtr.Size != 4)
            {
                throw new InvalidOperationException("not_x86");
            }
            var sdkDir = System.IO.Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
                "Brother",
                "iPrint&Scan");
            var commonPath = System.IO.Path.Combine(sdkDir, "BRAppDevKitCommon.dll");
            var queryPath = System.IO.Path.Combine(sdkDir, "BRAppDevKitQuery2.dll");
            if (!System.IO.File.Exists(commonPath) || !System.IO.File.Exists(queryPath))
            {
                throw new InvalidOperationException("sdk_missing");
            }

            var common = Assembly.LoadFrom(commonPath);
            var query = Assembly.LoadFrom(queryPath);
            var deviceInfoType = Require(common, "Brooklyn.AppDevKit.Common.DeviceInfo");
            var connectionType = Require(common, "Brooklyn.AppDevKit.Common.DeviceConnectionInfo");
            var interfaceEnum = Require(common, "Brooklyn.AppDevKit.Common.ConnectionType");
            var categoryType = Require(common, "Brooklyn.AppDevKit.Common.DeviceCategory");

            var deviceInfo = Activator.CreateInstance(deviceInfoType);
            var connection = Activator.CreateInstance(connectionType);
            Set(connection, "Interface", Enum.Parse(interfaceEnum, "USB"));
            Set(connection, "VendorID", 0x04F9);
            Set(connection, "ProductID", 0x04F5);
            Set(connection, "Location", "USB");
            Set(deviceInfo, "ConnectionInfo", connection);
            Set(deviceInfo, "ModelName", "HL-L3280CDW series");
            Set(deviceInfo, "VendorName", "Brother");
            Set(deviceInfo, "Category", Enum.Parse(categoryType, "LaserOrLED"));

            var helper = Require(query, "Brooklyn.AppDevKit.Query2.LibraryInterface.SDK.SdkDeviceInformation.DiscoveryDeviceHelper");
            InvokeStatic(helper, "ToQuerySdkDeviceInformation", new object[] { deviceInfo }, OpenWaitMs);

            var factory = Require(query, "Brooklyn.AppDevKit.Query2.Device.USB.USBDeviceCreater");
            var created = InvokeStatic(
                factory,
                "CreateHttpOverUSBDeviceAsync",
                new object[]
                {
                    deviceInfo,
                    CultureInfo.GetCultureInfo("en-US"),
                    TimeSpan.FromSeconds(15),
                    CancellationToken.None,
                    false,
                },
                OpenWaitMs);
            if (created == null)
            {
                throw new InvalidOperationException("usb_open_failed");
            }
            _device = created;
            _firmwareRead = false;
        }

        void ReadStatus(Snapshot snapshot)
        {
            var status = Invoke(_device, "QueryStatus", new object[] { CancellationToken.None }, FastCallMs);
            if (status == null) return;
            snapshot.StatusCode = AsInt(Get(status, "StatusCode"));
            snapshot.StatusMessage = AsString(Get(status, "StatusMessage"));
            snapshot.StatusType = AsString(Get(status, "StatusType"));
            var supplies = Get(status, "Supplies") as IEnumerable;
            if (supplies == null) return;
            foreach (var supply in supplies)
            {
                if (supply == null) continue;
                var detail = AsString(Get(supply, "DetailedType"));
                var current = AsDouble(Get(supply, "CurrentNum"));
                var max = AsDouble(Get(supply, "MaxNum"));
                if (detail == null || !current.HasValue || !max.HasValue || max.Value <= 0) continue;
                var percent = (int)Math.Round(current.Value / max.Value * 100.0);
                if (percent < 0 || percent > 100) continue;
                var name = detail.ToLowerInvariant();
                if (name.Contains("black")) snapshot.TonerBlack = percent;
                else if (name.Contains("cyan")) snapshot.TonerCyan = percent;
                else if (name.Contains("magenta")) snapshot.TonerMagenta = percent;
                else if (name.Contains("yellow")) snapshot.TonerYellow = percent;
            }
        }

        void ReadPageCounts(Snapshot snapshot)
        {
            var raw = Invoke(_device, "QueryPageCountInfo", new object[] { null }, FastCallMs);
            BrotherRecords.Apply(HexToBytes(AsString(raw)), snapshot, pages: true);
        }

        void ReadNextCare(Snapshot snapshot)
        {
            var raw = Invoke(_device, "QueryNextCareInfo", new object[] { null }, FastCallMs);
            BrotherRecords.Apply(HexToBytes(AsString(raw)), snapshot, pages: false);
        }

        void ReadMaintenance(Snapshot snapshot)
        {
            try
            {
                var raw = Invoke(_device, "QueryMaintenceInfo", new object[] { null }, FastCallMs);
                BrotherRecords.ApplyToner(HexToBytes(AsString(raw)), snapshot);
            }
            catch
            {
                // Toner stays at the QueryStatus fallback. Page counts already succeeded.
            }
        }

        void ReadFirmwareOnce(Snapshot snapshot)
        {
            if (!_firmwareRead)
            {
                var info = Invoke(_device, "QueryFirmwareInformation", new object[] { CancellationToken.None }, FastCallMs);
                ReadFirmwareObject(info);
                _firmwareRead = true;
            }
            snapshot.FirmwareMain = _firmwareMain;
            snapshot.FirmwareSub3 = _firmwareSub3;
            snapshot.Model = _model;
            snapshot.SerialNumber = _serial;
        }

        void ReadFirmwareObject(object info)
        {
            if (info == null) return;
            if (info is string firmwareText)
            {
                _firmwareMain = firmwareText;
                return;
            }
            foreach (var prop in info.GetType().GetProperties(BindingFlags.Instance | BindingFlags.Public))
            {
                if (!prop.CanRead || prop.GetIndexParameters().Length != 0) continue;
                object value;
                try { value = prop.GetValue(info, null); }
                catch { continue; }
                var propText = AsString(value);
                if (string.IsNullOrWhiteSpace(propText)) continue;
                var name = prop.Name.ToLowerInvariant();
                if (name.Contains("sub3") || name.Contains("subfirmware")) _firmwareSub3 = propText;
                else if (name.Contains("serial")) _serial = propText;
                else if (name.Contains("model")) _model = propText;
                else if (name.Contains("main")) _firmwareMain = propText;
            }
        }

        void ReadErrorHistory(Snapshot snapshot)
        {
            snapshot.ErrorHistoryIncluded = true;
            for (var i = 0; i <= 10; i++)
            {
                object description;
                object pageCount;
                try
                {
                    pageCount = Invoke(
                        _device,
                        "QueryErrorHistoryPageCount",
                        new object[] { (uint)i, null },
                        FastCallMs);
                    description = Invoke(
                        _device,
                        "QueryErrorHistoryDescription",
                        new object[] { (uint)i, null },
                        FastCallMs);
                }
                catch
                {
                    continue;
                }
                var text = AsString(description);
                var pages = AsInt(pageCount);
                if (string.IsNullOrWhiteSpace(text) && (pages == null || pages == 0)) continue;
                if (text != null)
                {
                    text = text.Trim();
                    if (text.Length > 160) text = text.Substring(0, 160);
                }
                snapshot.ErrorHistory.Add(new HistoryEntry
                {
                    Index = i,
                    Description = text,
                    PageCount = pages,
                });
            }
        }

        void DropDevice()
        {
            var device = _device;
            _device = null;
            _firmwareRead = false;
            if (device == null) return;
            try
            {
                var disposable = device as IDisposable;
                if (disposable != null) disposable.Dispose();
            }
            catch
            {
                // The next open creates a new device.
            }
        }

        static Type Require(Assembly assembly, string name)
        {
            var type = assembly.GetType(name, false);
            if (type == null) throw new InvalidOperationException("sdk_type_missing");
            return type;
        }

        static void Set(object target, string name, object value)
        {
            var prop = target.GetType().GetProperty(name, BindingFlags.Instance | BindingFlags.Public);
            if (prop == null) throw new MissingMemberException(target.GetType().FullName, name);
            var dest = prop.PropertyType;
            object converted = value;
            if (value != null && dest.IsEnum)
            {
                converted = value is string text ? Enum.Parse(dest, text) : Enum.ToObject(dest, value);
            }
            else if (value != null && !dest.IsInstanceOfType(value))
            {
                converted = Convert.ChangeType(value, Nullable.GetUnderlyingType(dest) ?? dest, CultureInfo.InvariantCulture);
            }
            prop.SetValue(target, converted, null);
        }

        static object Get(object target, string name)
        {
            var prop = target.GetType().GetProperty(name, BindingFlags.Instance | BindingFlags.Public);
            if (prop == null || !prop.CanRead) return null;
            return prop.GetValue(target, null);
        }

        static object Invoke(object target, string name, object[] args, int waitMs)
        {
            var methods = target.GetType()
                .GetMethods(BindingFlags.Instance | BindingFlags.Public)
                .Where(candidate => candidate.Name == name && candidate.GetParameters().Length == args.Length)
                .ToArray();
            if (methods.Length == 0) throw new MissingMethodException(target.GetType().FullName, name);
            var method = Choose(methods, args);
            return Unwrap(method.Invoke(target, Fit(method, args)), waitMs);
        }

        static object InvokeStatic(Type type, string name, object[] args, int waitMs)
        {
            var methods = type
                .GetMethods(BindingFlags.Static | BindingFlags.Public)
                .Where(candidate => candidate.Name == name && candidate.GetParameters().Length == args.Length)
                .ToArray();
            if (methods.Length == 0) throw new MissingMethodException(type.FullName, name);
            var method = Choose(methods, args);
            return Unwrap(method.Invoke(null, Fit(method, args)), waitMs);
        }

        static MethodInfo Choose(MethodInfo[] methods, object[] args)
        {
            if (methods.Length == 1) return methods[0];
            MethodInfo best = methods[0];
            var bestScore = -1;
            foreach (var method in methods)
            {
                var score = 0;
                var parameters = method.GetParameters();
                for (var i = 0; i < parameters.Length; i++)
                {
                    var arg = args[i];
                    var param = parameters[i].ParameterType;
                    if (arg == null)
                    {
                        if (!param.IsValueType || Nullable.GetUnderlyingType(param) != null) score += 2;
                    }
                    else if (param.IsInstanceOfType(arg))
                    {
                        score += 3;
                    }
                }
                if (score > bestScore)
                {
                    bestScore = score;
                    best = method;
                }
            }
            return best;
        }

        static object[] Fit(MethodInfo method, object[] args)
        {
            var parameters = method.GetParameters();
            var fitted = new object[args.Length];
            for (var i = 0; i < args.Length; i++)
            {
                var arg = args[i];
                var dest = parameters[i].ParameterType;
                if (arg == null)
                {
                    fitted[i] = dest.IsValueType && Nullable.GetUnderlyingType(dest) == null
                        ? Activator.CreateInstance(dest)
                        : null;
                    continue;
                }
                if (dest.IsInstanceOfType(arg))
                {
                    fitted[i] = arg;
                    continue;
                }
                var underlying = Nullable.GetUnderlyingType(dest) ?? dest;
                fitted[i] = Convert.ChangeType(arg, underlying, CultureInfo.InvariantCulture);
            }
            return fitted;
        }

        static object Unwrap(object value, int waitMs)
        {
            var task = value as Task;
            if (task == null) return value;
            if (!task.Wait(waitMs))
            {
                throw new TimeoutException("usb_timeout");
            }
            if (task.IsFaulted)
            {
                throw task.Exception == null ? new InvalidOperationException("usb_call_failed") : task.Exception.GetBaseException();
            }
            var result = task.GetType().GetProperty("Result");
            if (result == null || !result.CanRead) return null;
            return result.GetValue(task, null);
        }

        static byte[] HexToBytes(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return new byte[0];
            var hex = value.Trim();
            if (hex.StartsWith("0x", StringComparison.OrdinalIgnoreCase)) hex = hex.Substring(2);
            var chars = new List<char>(hex.Length);
            foreach (var c in hex)
            {
                if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))
                {
                    chars.Add(c);
                }
            }
            if (chars.Count == 0 || (chars.Count % 2) != 0) return new byte[0];
            var bytes = new byte[chars.Count / 2];
            for (var i = 0; i < bytes.Length; i++)
            {
                bytes[i] = Convert.ToByte(new string(chars.GetRange(i * 2, 2).ToArray()), 16);
            }
            return bytes;
        }

        static int? AsInt(object value)
        {
            if (value == null) return null;
            if (value is int number) return number;
            if (value is uint unsigned) return unsigned > int.MaxValue ? (int?)null : (int)unsigned;
            if (value is long wide)
            {
                if (wide < int.MinValue || wide > int.MaxValue) return null;
                return (int)wide;
            }
            if (value.GetType().IsEnum) return Convert.ToInt32(value, CultureInfo.InvariantCulture);
            int parsed;
            return int.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, out parsed)
                ? (int?)parsed
                : null;
        }

        static double? AsDouble(object value)
        {
            if (value == null) return null;
            try
            {
                return Convert.ToDouble(value, CultureInfo.InvariantCulture);
            }
            catch
            {
                return null;
            }
        }

        static string AsString(object value)
        {
            if (value == null) return null;
            var text = Convert.ToString(value, CultureInfo.InvariantCulture);
            return string.IsNullOrWhiteSpace(text) ? null : text.Trim();
        }

        static string OneLine(Exception ex)
        {
            var inner = ex.GetBaseException();
            var message = inner == null ? ex.Message : inner.Message;
            if (string.IsNullOrWhiteSpace(message)) return "usb_helper_failed";
            return message.Replace("\r", " ").Replace("\n", " ").Trim();
        }
    }
}
