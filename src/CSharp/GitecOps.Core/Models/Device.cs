using System.Text.RegularExpressions;

namespace GitecOps.Core.Models;

public class Device
{
    private static readonly Regex HyphenRegex = new(@"^CTE-([A-Z]?\d{3})-V(\d{4,5})$", RegexOptions.IgnoreCase);
    private static readonly Regex CompactRegex = new(@"^CTE([A-Z]?\d{3})V(\d{4,5})$", RegexOptions.IgnoreCase);
    private static readonly Regex ExtendedRegex = new(@"^CTEV(\d{3,4})V(\d{5})$", RegexOptions.IgnoreCase);

    public Device(string deviceName)
    {
        DeviceName = deviceName.ToUpperInvariant();
        NormalizedName = NormalizeName(DeviceName);
        IsValidDeviceName = string.Equals(DeviceName, NormalizedName, StringComparison.OrdinalIgnoreCase);
        AssetNumber = NormalizedName.Split('-')[2];
        SerialNumber = string.Empty;
    }

    public string DeviceName { get; set; }
    public string NormalizedName { get; private init; }
    public bool IsValidDeviceName { get; private init; }
    public string SerialNumber { get; set; }
    public string AssetNumber { get; set; }
    public float TotalRam { get; set; } // in GB
    public SystemOs OperatingSystem { get; set; } = new();
    public ICollection<Drive> Drives { get; } = new List<Drive>();
    public ICollection<Update> Updates { get; } = new List<Update>();

    public void AddUpdate(Update update)
    {
        ArgumentNullException.ThrowIfNull(update);
        Updates.Add(update);
    }

    public void AddDrive(Drive drive)
    {
        ArgumentNullException.ThrowIfNull(drive);
        Drives.Add(drive);
    }

    private static string NormalizeName(string name)
    {
        if (HyphenRegex.IsMatch(name))
            return name;

        if (CompactRegex.Match(name) is { Success: true } compactMatch)
            return $"CTE-{compactMatch.Groups[1].Value}-V{compactMatch.Groups[2].Value}";

        if (ExtendedRegex.Match(name) is { Success: true } extendedMatch)
            return $"CTE-V{extendedMatch.Groups[1].Value}-V{extendedMatch.Groups[2].Value}";

        throw new ArgumentException($"Invalid device name format: {name}");
    }

    public enum DeviceTypeEnum
    {
        Unknown,
        Server,
        Workstation,
        Other
    }
}

public class Drive
{
    public Drive() : this('C', 0, 0, DriveType.Unknown) { }

    public Drive(char driveLetter, float size, float used, DriveType driveType = DriveType.Unknown)
    {
        DriveLetter = driveLetter;
        Size = size;
        Used = used;
        DriveType = driveType;
        Free = size - used;
        PercentUsed = size > 0 ? (used / size) * 100 : 0;
    }

    public char DriveLetter { get; set; }
    public float Size { get; set; }
    public float Used { get; set; }
    public float Free { get; set; }
    public float PercentUsed { get; set; }
    public DriveType DriveType { get; set; }
}

public class SystemOs
{
    public string OperatingSystem { get; set; } = string.Empty;
    public string Version { get; set; } = string.Empty;
    public string ServicePack { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty;
}

public class Update
{
    public string HotfixId { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string InstalledOn { get; set; } = string.Empty;
}
