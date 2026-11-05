using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text.RegularExpressions;

namespace SkpPrinterUsb
{
    /// <summary>
    /// Pure HTML parsers for DCP-T830DW HttpToUsbBridge pages.
    /// </summary>
    static class BridgeHtml
    {
        static readonly Regex MonitorFragment = new Regex(
            @"monitor_start[^>]*>\s*<span\s+class=""moni\s+([^""]+)"">([^<]*)</span>",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

        static readonly Regex DtDd = new Regex(
            @"<dt[^>]*>(.*?)</dt>\s*<dd[^>]*>(.*?)</dd>",
            RegexOptions.IgnoreCase | RegexOptions.Singleline | RegexOptions.CultureInvariant);

        static readonly Regex TableRow = new Regex(
            @"<tr[^>]*>(.*?)</tr>",
            RegexOptions.IgnoreCase | RegexOptions.Singleline | RegexOptions.CultureInvariant);

        static readonly Regex TableCell = new Regex(
            @"<t[hd][^>]*>(.*?)</t[hd]>",
            RegexOptions.IgnoreCase | RegexOptions.Singleline | RegexOptions.CultureInvariant);

        static readonly Regex Tag = new Regex(@"<[^>]+>", RegexOptions.CultureInvariant);

        public static void ApplyMonitor(string html, Snapshot snapshot)
        {
            if (string.IsNullOrEmpty(html) || snapshot == null) return;
            var match = MonitorFragment.Match(html);
            if (!match.Success) return;
            var css = match.Groups[1].Value.Trim();
            var text = Decode(match.Groups[2].Value).Trim();
            snapshot.StatusMessage = string.IsNullOrEmpty(text) ? null : text;
            snapshot.StatusType = StatusTypeFromClass(css);
            snapshot.StatusCode = StatusCodeFromMessage(text);
        }

        public static void ApplyMaintenance(string html, Snapshot snapshot, bool includeErrors)
        {
            if (string.IsNullOrEmpty(html) || snapshot == null) return;
            var awaitingPageColour = false;
            var acceptDuplex = true;
            foreach (Match pair in DtDd.Matches(html))
            {
                var label = NormalizeLabel(Decode(StripTags(pair.Groups[1].Value)));
                var value = Decode(StripTags(pair.Groups[2].Value)).Trim();
                if (label.Length == 0) continue;

                if (label.Equals("Copy", StringComparison.OrdinalIgnoreCase))
                {
                    acceptDuplex = false;
                    continue;
                }
                if (label.Equals("Page Counter", StringComparison.OrdinalIgnoreCase))
                {
                    snapshot.PagesTotal = ParseInt(value);
                    awaitingPageColour = true;
                    continue;
                }
                if (awaitingPageColour && label.Equals("Colour", StringComparison.OrdinalIgnoreCase))
                {
                    snapshot.PagesColor = ParseInt(value);
                    continue;
                }
                if (awaitingPageColour &&
                    (label.Equals("B&W", StringComparison.OrdinalIgnoreCase) ||
                     label.Equals("B&amp;W", StringComparison.OrdinalIgnoreCase) ||
                     label.Equals("Black and White", StringComparison.OrdinalIgnoreCase)))
                {
                    snapshot.PagesBlackAndWhite = ParseInt(value);
                    awaitingPageColour = false;
                    continue;
                }
                if (acceptDuplex && label.Equals("2-sided Print", StringComparison.OrdinalIgnoreCase))
                {
                    if (!snapshot.PagesDuplexTotal.HasValue)
                    {
                        snapshot.PagesDuplexTotal = ParseInt(value);
                    }
                    continue;
                }
                if (acceptDuplex && label.Equals("Colour 2-sided", StringComparison.OrdinalIgnoreCase))
                {
                    if (!snapshot.PagesDuplexColor.HasValue)
                    {
                        snapshot.PagesDuplexColor = ParseInt(value);
                    }
                    continue;
                }
                if (acceptDuplex &&
                    (label.Equals("B&W 2-sided", StringComparison.OrdinalIgnoreCase) ||
                     label.Equals("B&amp;W 2-sided", StringComparison.OrdinalIgnoreCase)))
                {
                    if (!snapshot.PagesDuplexBlackAndWhite.HasValue)
                    {
                        snapshot.PagesDuplexBlackAndWhite = ParseInt(value);
                    }
                    continue;
                }
                if (label.StartsWith("Ink", StringComparison.OrdinalIgnoreCase) && value.IndexOf('%') >= 0)
                {
                    var percent = ParsePercent(value);
                    if (!percent.HasValue) continue;
                    if (label.IndexOf("Black", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        label.IndexOf("(BK)", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        snapshot.TonerBlack = percent;
                    }
                    else if (label.IndexOf("Cyan", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        snapshot.TonerCyan = percent;
                    }
                    else if (label.IndexOf("Magenta", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        snapshot.TonerMagenta = percent;
                    }
                    else if (label.IndexOf("Yellow", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        snapshot.TonerYellow = percent;
                    }
                    awaitingPageColour = false;
                    continue;
                }
                if (label.StartsWith("Ink", StringComparison.OrdinalIgnoreCase) && value.IndexOf('%') < 0)
                {
                    var count = ParseInt(value);
                    if (!count.HasValue) continue;
                    if (label.IndexOf("Black", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        label.IndexOf("(BK)", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        snapshot.RefillBlack = count;
                    }
                    else if (label.IndexOf("Cyan", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        snapshot.RefillCyan = count;
                    }
                    else if (label.IndexOf("Magenta", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        snapshot.RefillMagenta = count;
                    }
                    else if (label.IndexOf("Yellow", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        snapshot.RefillYellow = count;
                    }
                    continue;
                }
                if (label.Equals("Model Name", StringComparison.OrdinalIgnoreCase))
                {
                    snapshot.Model = EmptyToNull(value);
                    continue;
                }
                if (label.Equals("Serial no.", StringComparison.OrdinalIgnoreCase) ||
                    label.Equals("Serial No.", StringComparison.OrdinalIgnoreCase) ||
                    label.Equals("Serial Number", StringComparison.OrdinalIgnoreCase))
                {
                    snapshot.SerialNumber = EmptyToNull(value);
                    continue;
                }
                if (label.Equals("Main Firmware Version", StringComparison.OrdinalIgnoreCase))
                {
                    snapshot.FirmwareMain = EmptyToNull(value);
                }
            }

            if (!includeErrors) return;
            snapshot.ErrorHistoryIncluded = true;
            snapshot.ErrorHistory.Clear();
            foreach (Match row in TableRow.Matches(html))
            {
                var cells = new List<string>();
                foreach (Match cell in TableCell.Matches(row.Groups[1].Value))
                {
                    cells.Add(Decode(StripTags(cell.Groups[1].Value)).Trim());
                }
                if (cells.Count < 2) continue;
                int index;
                if (!int.TryParse(cells[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out index))
                {
                    continue;
                }
                if (index < 1 || index > 10) continue;
                var description = cells[1];
                if (string.IsNullOrWhiteSpace(description)) continue;
                if (description.Length > 160) description = description.Substring(0, 160);
                snapshot.ErrorHistory.Add(new HistoryEntry
                {
                    Index = index,
                    Description = description,
                });
            }
        }

        public static int? StatusCodeFromMessage(string message)
        {
            if (string.IsNullOrWhiteSpace(message)) return null;
            var text = message.Trim();
            if (Contains(text, "sleep")) return 40000;
            if (Contains(text, "printing")) return 10023;
            if (Contains(text, "please wait") || text.Equals("Wait", StringComparison.OrdinalIgnoreCase))
            {
                return 10003;
            }
            if (Contains(text, "ready") || Contains(text, "idle")) return 10001;
            if (IsPaperOut(text)) return 41236;
            return null;
        }

        static bool IsPaperOut(string text)
        {
            if (Contains(text, "out of paper")) return true;
            if (Contains(text, "paper empty")) return true;
            if (Contains(text, "no paper")) return true;
            if (Contains(text, "load paper")) return true;
            if (Contains(text, "paper tray") &&
                (Contains(text, "empty") || Contains(text, "not detected") || Contains(text, "out")))
            {
                return true;
            }
            return false;
        }

        static string StatusTypeFromClass(string css)
        {
            if (string.IsNullOrEmpty(css)) return null;
            if (Contains(css, "moniError")) return "Error";
            if (Contains(css, "moniWarning")) return "Warning";
            if (Contains(css, "moniOk")) return "Ready";
            if (Contains(css, "moniEtc")) return "Etc";
            return css;
        }

        static string StripTags(string value)
        {
            if (string.IsNullOrEmpty(value)) return "";
            return Tag.Replace(value, "");
        }

        static string Decode(string value)
        {
            if (string.IsNullOrEmpty(value)) return "";
            return value
                .Replace("&#32;", " ")
                .Replace("&nbsp;", " ")
                .Replace("&amp;", "&")
                .Replace("&lt;", "<")
                .Replace("&gt;", ">")
                .Replace("&quot;", "\"")
                .Replace('\u00A0', ' ');
        }

        static string NormalizeLabel(string label)
        {
            if (string.IsNullOrEmpty(label)) return "";
            return Regex.Replace(label.Trim(), @"\s+", " ");
        }

        static int? ParseInt(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return null;
            var digits = Regex.Match(value, @"-?\d+");
            if (!digits.Success) return null;
            int number;
            if (!int.TryParse(digits.Value, NumberStyles.Integer, CultureInfo.InvariantCulture, out number))
            {
                return null;
            }
            if (number < 0) return null;
            return number;
        }

        static int? ParsePercent(string value)
        {
            var number = ParseInt(value);
            if (!number.HasValue || number.Value > 100) return null;
            return number;
        }

        static string EmptyToNull(string value)
        {
            return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        }

        static bool Contains(string haystack, string needle)
        {
            return haystack.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0;
        }
    }
}
