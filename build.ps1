$ProjectDir = "D:\GitecOps.Project"
$SourceDir = Join-Path -Path $ProjectDir -ChildPath "PsBuildRoot"
$PsBuildDir =  "C:\Program Files\GitecOps"
$AssetDir = Join-Path -Path $PsBuildDir -ChildPath "assets"
$scriptDir = Join-Path -Path $PsBuildDir -ChildPath "scripts"
$ModuleDir = Join-Path -Path $PsBuildDir -ChildPath "modules"
$LogsDir = Join-Path -Path $PsBuildDir -ChildPath "logs"
$LogFile = Join-Path -Path $LogsDir -ChildPath "events.log"

# Create the build directory if it doesn't exist
if (-not (Test-Path -Path $PsBuildDir)) {
    New-Item -ItemType Directory -Path $PsBuildDir
}
#empty the build directory
Get-ChildItem -Path $PsBuildDir -Recurse | Remove-Item -Force -Recurse
# Create the assets directory if it doesn't exist
if (-not (Test-Path -Path $AssetDir)) {
    New-Item -ItemType Directory -Path $AssetDir
}
# Create the scripts directory if it doesn't exist
if (-not (Test-Path -Path $scriptDir)) {
    New-Item -ItemType Directory -Path $scriptDir
}
# Create the modules directory if it doesn't exist
if (-not (Test-Path -Path $ModuleDir)) {
    New-Item -ItemType Directory -Path $ModuleDir
}
# Create the logs directory if it doesn't exist
if (-not (Test-Path -Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir
}
# Create the logs file if it doesn't exist
if (-not (Test-Path -Path $LogFile)) {
    New-Item -ItemType File -Path $LogFile
}

# Import Logging module
$LoggingModulePath = Join-Path -Path $SourceDir -ChildPath "modules\Logging.psm1"
if (-not (Test-Path -Path $LoggingModulePath)) {
    Write-Host "Logging module not found at $LoggingModulePath"
    exit 1
}

Import-Module -Name $LoggingModulePath -Force
Write-Info -Message "Logging module imported from $LoggingModulePath"

$appsList = @(
    "GitecOps.Util"
)

foreach ($app in $appsList) {
    $appPath = Join-Path -Path $ProjectDir -ChildPath "src\CSharp\$app\bin\Debug\net9.0\$app.exe"
    if (-not (Test-Path -Path $appPath)) {
        Write-Host "$app executable not found at $appPath"
        exit 1
    }
    # Copy the application executable to the build directory
    Copy-Item -Path $appPath -Destination $AssetDir -Force
    Write-Info -Message "$app executable copied to $AssetDir"
}


# Copy the contents of the source directory to the build directory
Copy-Item -Path (Join-Path -Path $SourceDir -ChildPath "assets\*") -Destination $AssetDir -Recurse -Force
Write-Info -Message "Assets copied to $AssetDir"
Copy-Item -Path (Join-Path -Path $SourceDir -ChildPath "scripts\*") -Destination $scriptDir -Recurse -Force
Write-Info -Message "Scripts copied to $scriptDir"
Copy-Item -Path (Join-Path -Path $SourceDir -ChildPath "modules\*") -Destination $ModuleDir -Recurse -Force
Write-Info -Message "Modules copied to $ModuleDir"
