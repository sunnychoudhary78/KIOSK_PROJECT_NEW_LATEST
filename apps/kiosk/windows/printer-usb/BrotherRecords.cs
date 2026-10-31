using System.Collections.Generic;

namespace SkpPrinterUsb
{
    /// <summary>
    /// Brother maintenance blobs: tag, 0x01, 0x04, four big-endian bytes.
    /// 0xFFFFFF is padding. 0xFFFFFFFF ends the blob.
    /// Known ids only: pages 0/1/2, next-care 136 (belt) / 115 (fuser),
    /// and toner 129 black / 130 cyan / 131 magenta / 132 yellow.
    /// </summary>
    static class BrotherRecords
    {
        public static void Apply(byte[] data, Snapshot snapshot, bool pages)
        {
            if (data == null || snapshot == null)
            {
                return;
            }
            foreach (var record in Decode(data))
            {
                if (!record.Value.HasValue)
                {
                    continue;
                }
                var value = (int)record.Value.Value;
                if (value < 0)
                {
                    continue;
                }
                if (pages)
                {
                    if (record.Id == 0) snapshot.PagesTotal = value;
                    else if (record.Id == 1) snapshot.PagesBlackAndWhite = value;
                    else if (record.Id == 2) snapshot.PagesColor = value;
                }
                else
                {
                    if (record.Id == 136) snapshot.BeltRemainingPages = value;
                    else if (record.Id == 115) snapshot.FuserRemainingPages = value;
                }
            }
        }

        /// Ids 129-132 only. 0 through 100 overwrites that color. Above 100 is ignored.
        public static void ApplyToner(byte[] data, Snapshot snapshot)
        {
            if (data == null || snapshot == null)
            {
                return;
            }
            foreach (var record in Decode(data))
            {
                if (!record.Value.HasValue || record.Value.Value > 100)
                {
                    continue;
                }
                var percent = (int)record.Value.Value;
                if (record.Id == 129) snapshot.TonerBlack = percent;
                else if (record.Id == 130) snapshot.TonerCyan = percent;
                else if (record.Id == 131) snapshot.TonerMagenta = percent;
                else if (record.Id == 132) snapshot.TonerYellow = percent;
            }
        }

        public static List<Record> Decode(byte[] data)
        {
            var records = new List<Record>();
            if (data == null)
            {
                return records;
            }
            var i = 0;
            while (i < data.Length)
            {
                if (i + 4 <= data.Length &&
                    data[i] == 0xFF && data[i + 1] == 0xFF &&
                    data[i + 2] == 0xFF && data[i + 3] == 0xFF)
                {
                    break;
                }
                if (i + 3 <= data.Length &&
                    data[i] == 0xFF && data[i + 1] == 0xFF && data[i + 2] == 0xFF)
                {
                    i += 3;
                    continue;
                }
                if (data[i] == 0xFF && i + 1 == data.Length)
                {
                    break;
                }
                if (i + 3 > data.Length || data[i + 1] != 0x01 || data[i + 2] != 0x04)
                {
                    break;
                }
                var tag = data[i];
                i += 3;
                var valueBytes = new byte[4];
                var count = 0;
                while (count < 4 && i < data.Length)
                {
                    if (i + 3 <= data.Length &&
                        data[i] == 0xFF && data[i + 1] == 0xFF && data[i + 2] == 0xFF)
                    {
                        i += 3;
                        continue;
                    }
                    valueBytes[count++] = data[i++];
                }
                if (count != 4)
                {
                    break;
                }
                uint value = ((uint)valueBytes[0] << 24) |
                             ((uint)valueBytes[1] << 16) |
                             ((uint)valueBytes[2] << 8) |
                             valueBytes[3];
                records.Add(new Record { Id = tag, Value = value });
            }
            return records;
        }

        public struct Record
        {
            public int Id;
            public uint? Value;
        }
    }
}
