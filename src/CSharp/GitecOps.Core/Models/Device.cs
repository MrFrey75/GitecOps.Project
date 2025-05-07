using System;
using System.Text.RegularExpressions;

namespace GitecOps.Core.Models
{
    public class Drive
    {
        public float Size { get; set; } // in gb
        public float Used { get; set; } // in gb
        public float Free { get; set; } // in gb
        public float PercentUsed { get; set; } // in percent

        public Drive(float size, float used)
        {
            Size = size;
            Used = used;
            Free = size - used;
            PercentUsed = (used / size) * 100;
        }
    }
    public class Device
    {
        public Device(string deviceName, DeviceTypeEnum deviceType = DeviceTypeEnum.Unknown)
        {
            DeviceName = deviceName;
            DeviceType = deviceType;
            NormalizedName = NormalizeName(deviceName);
            IsValidDeviceName = string.Equals(DeviceName, NormalizedName, StringComparison.OrdinalIgnoreCase);
        }

        public string DeviceName { get; set; }
        public DeviceTypeEnum DeviceType { get; set; }
        public string NormalizedName { get; private set; }
        public bool IsValidDeviceName { get; private set; }
        public ICollection<Drive> Drives { get; } = [];
        
        public void AddDrive(Drive drive)
        {
            if (drive == null)
            {
                throw new ArgumentNullException(nameof(drive), "Drive cannot be null");
            }
            Drives.Add(drive);
        }

        private string NormalizeName(string name)
        {
            var upperName = name.ToUpperInvariant();

            // Valid hyphenated: CTE-123-V1234 or CTE-123-V12345
            var regexHyphen = new Regex(@"^CTE-(\d{3})-V(\d{4,5})$", RegexOptions.IgnoreCase);

            // Compact: CTE123V1234 or CTE123V12345
            var regexCompact = new Regex(@"^CTE(\d{3})V(\d{4,5})$", RegexOptions.IgnoreCase);

            // Extended compact: CTEV123V12345
            var regexExtended = new Regex(@"^CTEV(\d{3,4})V(\d{5})$", RegexOptions.IgnoreCase);

            if (regexHyphen.IsMatch(upperName))
            {
                return upperName;
            }

            if (regexCompact.IsMatch(upperName))
            {
                var match = regexCompact.Match(upperName);
                return $"CTE-{match.Groups[1].Value}-V{match.Groups[2].Value}";
            }

            if (regexExtended.IsMatch(upperName))
            {
                var match = regexExtended.Match(upperName);
                return $"CTE-V{match.Groups[1].Value}-V{match.Groups[2].Value}";
            }

            throw new ArgumentException($"Invalid device name format: {name}");
        }

        public enum DeviceTypeEnum
        {
            Unknown,
            Server,
            Router,
            Switch,
            Firewall,
            LoadBalancer,
            Storage,
            Other
        }
    }
}
