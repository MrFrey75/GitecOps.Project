using System;
using System.IO;
using System.Management;
using System.Threading.Tasks;
using GitecOps.Core.Models;

namespace GitecOps.Core.Services;

public class DeviceService
{
    public Device CurrentDevice { get; private set; }

    public DeviceService()
    {
        CurrentDevice = new Device(Environment.MachineName);
        InitializeDeviceAsync().Wait();
    }

    private async Task InitializeDeviceAsync()
    {
        await Task.WhenAll(
            GetDrivesAsync(),
            GetSystemMemoryAsync(),
            GetOperatingSystemInfoAsync(),
            GetSerialNumberAsync(),
            GetUpdatesAsync()
        );
    }

    private Task GetUpdatesAsync()
    {
        using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_QuickFixEngineering");

        foreach (ManagementObject item in searcher.Get())
        {
            CurrentDevice.AddUpdate(new Update
            {
                HotfixId = item["HotFixID"]?.ToString() ?? string.Empty,
                Description = item["Description"]?.ToString() ?? string.Empty,
                InstalledOn = item["InstalledOn"]?.ToString() ?? string.Empty
            });
        }

        return Task.CompletedTask;
    }

    private Task GetSerialNumberAsync()
    {
        using var searcher = new ManagementObjectSearcher("SELECT SerialNumber FROM Win32_BIOS");

        foreach (ManagementObject item in searcher.Get())
        {
            if (item["SerialNumber"] is string serial)
            {
                CurrentDevice.SerialNumber = serial;
                break;
            }
        }

        return Task.CompletedTask;
    }

    private Task GetOperatingSystemInfoAsync()
    {
        var os = Environment.OSVersion;

        CurrentDevice.OperatingSystem = new SystemOs
        {
            OperatingSystem = os.ToString(),
            Version = os.Version.ToString(),
            ServicePack = os.ServicePack,
            Platform = os.Platform.ToString()
        };

        return Task.CompletedTask;
    }

    private Task GetDrivesAsync()
    {
        foreach (var drive in DriveInfo.GetDrives())
        {
            if (!drive.IsReady) continue;

            var total = drive.TotalSize / (1024f * 1024 * 1024);
            var free = drive.AvailableFreeSpace / (1024f * 1024 * 1024);
            var used = total - free;

            CurrentDevice.AddDrive(new Drive(
                driveLetter: drive.Name[0],
                size: total,
                used: used,
                driveType: drive.DriveType
            ));
        }

        return Task.CompletedTask;
    }

    private Task GetSystemMemoryAsync()
    {
        long totalRam = 0;

        using var searcher = new ManagementObjectSearcher("SELECT Capacity FROM Win32_PhysicalMemory");
        foreach (ManagementObject item in searcher.Get())
        {
            switch (item["Capacity"])
            {
                case string capStr when long.TryParse(capStr, out var cap):
                    totalRam += cap;
                    break;
                case long capNum:
                    totalRam += capNum;
                    break;
            }
        }

        CurrentDevice.TotalRam = totalRam / (1024f * 1024 * 1024); // Bytes → GB
        return Task.CompletedTask;
    }
}
