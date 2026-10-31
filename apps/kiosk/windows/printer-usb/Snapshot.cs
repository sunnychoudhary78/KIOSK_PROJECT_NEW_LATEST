using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace SkpPrinterUsb
{
    sealed class Snapshot
    {
        public bool Ok;
        public bool Connected;
        public string Error;
        public int? StatusCode;
        public string StatusMessage;
        public string StatusType;
        public int? TonerBlack;
        public int? TonerCyan;
        public int? TonerMagenta;
        public int? TonerYellow;
        public int? PagesTotal;
        public int? PagesColor;
        public int? PagesBlackAndWhite;
        public int? BeltRemainingPages;
        public int? FuserRemainingPages;
        public string FirmwareMain;
        public string FirmwareSub3;
        public string Model;
        public string SerialNumber;
        public bool ErrorHistoryIncluded;
        public readonly List<HistoryEntry> ErrorHistory = new List<HistoryEntry>();

        public static Snapshot Fail(string error)
        {
            return new Snapshot
            {
                Ok = false,
                Connected = false,
                Error = error ?? "usb_helper_failed",
            };
        }

        public string ToJson()
        {
            var sb = new StringBuilder();
            sb.Append('{');
            var first = true;
            void Sep()
            {
                if (!first) sb.Append(',');
                first = false;
            }
            void Raw(string name, string jsonValue)
            {
                Sep();
                sb.Append('"').Append(name).Append("\":").Append(jsonValue);
            }
            void Str(string name, string value)
            {
                if (value == null) return;
                Sep();
                sb.Append('"').Append(name).Append("\":\"").Append(Esc(value)).Append('"');
            }
            void Num(string name, int? value)
            {
                if (!value.HasValue) return;
                Sep();
                sb.Append('"').Append(name).Append("\":").Append(value.Value.ToString(CultureInfo.InvariantCulture));
            }

            Raw("ok", Ok ? "true" : "false");
            Raw("connected", Connected ? "true" : "false");
            Str("error", Error);
            Num("statusCode", StatusCode);
            Str("statusMessage", StatusMessage);
            Str("statusType", StatusType);
            Num("tonerBlack", TonerBlack);
            Num("tonerCyan", TonerCyan);
            Num("tonerMagenta", TonerMagenta);
            Num("tonerYellow", TonerYellow);
            Num("pagesTotal", PagesTotal);
            Num("pagesColor", PagesColor);
            Num("pagesBlackAndWhite", PagesBlackAndWhite);
            Num("beltRemainingPages", BeltRemainingPages);
            Num("fuserRemainingPages", FuserRemainingPages);
            Str("firmwareMain", FirmwareMain);
            Str("firmwareSub3", FirmwareSub3);
            Str("model", Model);
            Str("serialNumber", SerialNumber);
            if (ErrorHistoryIncluded)
            {
                var entries = new StringBuilder();
                entries.Append('[');
                for (var i = 0; i < ErrorHistory.Count; i++)
                {
                    if (i > 0) entries.Append(',');
                    var entry = ErrorHistory[i];
                    entries.Append("{\"index\":").Append(entry.Index.ToString(CultureInfo.InvariantCulture));
                    if (entry.Description != null)
                    {
                        entries.Append(",\"description\":\"").Append(Esc(entry.Description)).Append('"');
                    }
                    entries.Append('}');
                }
                entries.Append(']');
                Raw("errorHistory", entries.ToString());
            }
            sb.Append('}');
            return sb.ToString();
        }

        static string Esc(string value)
        {
            if (string.IsNullOrEmpty(value)) return "";
            var sb = new StringBuilder(value.Length);
            foreach (var c in value)
            {
                if (c == '\\' || c == '"') sb.Append('\\').Append(c);
                else if (c == '\n') sb.Append("\\n");
                else if (c == '\r') sb.Append("\\r");
                else if (c < 32) continue;
                else sb.Append(c);
            }
            return sb.ToString();
        }
    }

    sealed class HistoryEntry
    {
        public int Index;
        public int? PageCount;
        public string Description;
    }
}
