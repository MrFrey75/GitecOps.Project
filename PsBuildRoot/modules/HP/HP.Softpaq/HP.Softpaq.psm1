# 
#  Copyright 2018-2025 HP Development Company, L.P.
#  All Rights Reserved.
# 
# NOTICE:  All information contained herein is, and remains the property of HP Development Company, L.P.
# 
# The intellectual and technical concepts contained herein are proprietary to HP Development Company, L.P
# and may be covered by U.S. and Foreign Patents, patents in process, and are protected by 
# trade secret or copyright law. Dissemination of this information or reproduction of this material
# is strictly forbidden unless prior written permission is obtained from HP Development Company, L.P.



Set-StrictMode -Version 3.0
#requires -Modules "HP.Private"
Add-Type -AssemblyName System.IO.Compression.FileSystem

<#
.SYNOPSIS
  Downloads the metadata of a SoftPaq metadata in CVA file format from ftp.hp.com or from a specified alternate server 

.DESCRIPTION
  This command downloads the metadata of a SoftPaq metadata in CVA file format from ftp.hp.com or from a specified alternate server. If the -URL parameter is not specified, the SoftPaq metadata is downloaded from ftp.hp.com. 

  Please note that this command is called in the Get-SoftPaqMetadataFile command if the -FriendlyName parameter is specified. 

.PARAMETER Number
  Specifies a SoftPaq number to retrieve the metadata from. Do not include any prefixes like 'SP' or any extensions like '.exe'. Please specify the SoftPaq number only.

.PARAMETER Url
  Specifies an alternate location for the SoftPaq URL. This URL must be HTTPS. The SoftPaq CVAs are expected to be at the location pointed to by this URL. If not specified, ftp.hp.com is used via HTTPS protocol.

.PARAMETER MaxRetries
  Specifies the maximum number of retries allowed to obtain an exclusive lock to downloaded files. This is relevant only when files are downloaded into a shared directory and multiple processes may be reading or writing from the same location.

  Current default value is 10 retries, and each retry includes a 30 second pause, which means the maximum time the default value will wait for an exclusive logs is 300 seconds or 5 minutes.

.EXAMPLE
  Get-SoftpaqMetadata -Number 1234 | Out-SoftpaqField -field Title

.LINK
  [Get-Softpaq](https://developers.hp.com/hp-client-management/doc/Get-Softpaq)

.LINK
  [Get-SoftpaqMetadataFile](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqMetadataFile)

.LINK
  [Get-SoftpaqList](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqList)

.LINK
  [Out-SoftpaqField](https://developers.hp.com/hp-client-management/doc/Out-SoftpaqField)

.LINK
  [Clear-SoftpaqCache](https://developers.hp.com/hp-client-management/doc/Clear-SoftpaqCache)
#>
function Get-SoftpaqMetadata {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-SoftpaqMetadata")]
  param(
    [ValidatePattern('^([Ss][Pp])*([0-9]{3,9})((\.[Ee][Xx][Ee]|\.[Cc][Vv][Aa])*)$')]
    [Parameter(Position = 0,Mandatory = $true)] [string]$Number,
    [Parameter(Position = 1,Mandatory = $false)] [string]$Url,
    [Parameter(Position = 2,Mandatory = $false)] [int]$MaxRetries = 0
  )

  # only allow https or file paths with or without file:// URL prefix
  if ($Url -and -not ($Url.StartsWith("https://",$true,$null) -or [System.IO.Directory]::Exists($Url) -or $Url.StartsWith("file://",$true,$null))) {
    throw [System.ArgumentException]"Only HTTPS or valid existing directory paths are supported."
  }

  $no = [int]$number.ToLower().TrimStart("sp").trimend(".exe").trimend('cva')
  [System.Net.ServicePointManager]::SecurityProtocol = Get-HPPrivateAllowedHttpsProtocols
  $loc = Get-HPPrivateItemUrl $no "cva" $url
  Get-HPPrivateReadINI -File $loc -Verbose:$VerbosePreference -maxRetries $maxRetries
}


<#
.SYNOPSIS
  Downloads a SoftPaq from ftp.hp.com or from a specified alternate server 

.DESCRIPTION
  This command downloads a SoftPaq from the default download server (ftp.hp.com) or from a specified alternate server.
  If using the default server, the download is performed over HTTPS. Otherwise, the protocol is dictated by the URL parameter.

  If a SoftPaq is either unavailable to download or has been obsoleted on the server, this command will display a warning that the SoftPaq could not be retrieved. 

  The Get-Softpaq command is not supported in WinPE.

.PARAMETER Number
  Specifies the SoftPaq number for which to retrieve the metadata. Do not include any prefixes like 'SP' or any extensions like '.exe'. Please specify the SoftPaq number only.

.PARAMETER SaveAs
  Specifies a specific file name to save the SoftPaq as. Otherwise, the name the SoftPaq will be saved as is inferred based on the remote name or the SoftPaq metadata if the FriendlyName parameter is specified.

.PARAMETER FriendlyName
  Specifies a friendly name for the downloaded SoftPaq based on the SoftPaq number and title

.PARAMETER Quiet
  If specified, this command will suppress non-essential messages during execution. 

.PARAMETER Overwrite
  Specifies the the overwrite behavior.
  The possible values include:
  "no" = (default if this parameter is not specified) do not overwrite existing files
  "yes" = force overwrite
  "skip" = skip existing files without any error

.PARAMETER Action
  Specifies the SoftPaq action this command will execute after download. The value must be either 'install' or 'silentinstall'. Silentinstall information is retrieved from the SoftPaq metadata (CVA) file. 
  If DestinationPath parameter is also specified, this value will be used as the location to save files. 

.PARAMETER Extract
  If specified, this command extracts SoftPaq content to a specified destination folder. Specify the destination folder with the DestinationPath parameter. 

  If the DestinationPath parameter is not specified, the files are extracted into a new sub-folder relative to the downloaded SoftPaq executable.

.PARAMETER DestinationPath
  Specifies the path to the folder in which you want to save downloaded and/or extracted files. Do not specify a file name or file name extension. 

  If not specified, the executable is downloaded to the current folder, and the files are extracted into a new sub-folder relative to the downloaded executable.

.PARAMETER Url
  Specifies an alternate location for the SoftPaq URL. This URL must be HTTPS. The SoftPaqs are expected to be at the location pointed to by this URL. If not specified, ftp.hp.com is used via HTTPS protocol.

.PARAMETER KeepInvalidSigned
  If specified, this command will not delete any files that failed the signature authentication check. This command performs a signature authentication check after a download. By default, this command will delete any downloaded file with an invalid or missing signature. 

.PARAMETER MaxRetries
  Specifies the maximum number of retries allowed to obtain an exclusive lock to downloaded files. This is relevant only when files are downloaded into a shared directory and multiple processes may be reading or writing from the same location.

  Current default value is 10 retries, and each retry includes a 30 second pause, which means the maximum time the default value will wait for an exclusive logs is 300 seconds or 5 minutes.

.EXAMPLE
    Get-Softpaq -Number 1234

.EXAMPLE
    Get-Softpaq -Number 1234 -Extract -DestinationPath "c:\staging\drivers"

.LINK
  [Get-SoftpaqMetadata](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqMetadata)

.LINK
  [Get-SoftpaqMetadataFile](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqMetadataFile)

.LINK
  [Get-SoftpaqList](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqList)

.LINK
  [Out-SoftpaqField](https://developers.hp.com/hp-client-management/doc/Out-SoftpaqField)

.LINK
  [Clear-SoftpaqCache](https://developers.hp.com/hp-client-management/doc/Clear-SoftpaqCache)

#>
function Get-Softpaq {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-Softpaq",DefaultParameterSetName = "DownloadParams")]
  param(
    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 0,Mandatory = $true)]
    [string]$Number,

    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 1,Mandatory = $false)]
    [string]$SaveAs,

    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 2,Mandatory = $false)]
    [switch]$FriendlyName,

    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 3,Mandatory = $false)]
    [switch]$Quiet,

    [Parameter(ParameterSetName = "DownloadParams")]
    [ValidateSet("no","yes","skip")]
    [Parameter(Position = 4,Mandatory = $false)]
    [string]$Overwrite = "no",

    [Parameter(Position = 5,Mandatory = $false,ParameterSetName = "DownloadParams")]
    [Parameter(Position = 5,Mandatory = $false,ParameterSetName = "InstallParams")]
    [ValidateSet("install","silentinstall")]
    [string]$Action,

    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 6,Mandatory = $false)]
    [string]$Url,

    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 7,Mandatory = $false)]
    [switch]$KeepInvalidSigned,

    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 8,Mandatory = $false)]
    [int]$MaxRetries = 0,

    [Parameter(Mandatory = $false,ParameterSetName = "DownloadParams")]
    [Parameter(Mandatory = $false,ParameterSetName = "ExtractParams")]
    [switch]$Extract,

    [Parameter(Mandatory = $false,ParameterSetName = "DownloadParams")]
    [Parameter(Mandatory = $false,ParameterSetName = "ExtractParams")]
    [ValidatePattern('^[a-zA-Z]:\\')]
    [string]$DestinationPath
  )

  if ((Test-WinPE) -and ($action)) {
    throw [NotSupportedException]"Softpaq installation is not supported in WinPE"
  }

   # only allow https or file paths with or without file:// URL prefix
  if ($Url -and -not ($Url.StartsWith("https://",$true,$null) -or [System.IO.Directory]::Exists($Url) -or $Url.StartsWith("file://",$true,$null))) {
    throw [System.ArgumentException]"Only HTTPS or valid existing directory paths are supported."
  }

  [System.Net.ServicePointManager]::SecurityProtocol = Get-HPPrivateAllowedHttpsProtocols
  $no = [int]$number.ToLower().TrimStart("sp").trimend(".exe")

  if ($keepInvalidSigned.IsPresent) { $keepInvalid = $true }
  else { $keepInvalid = $false }

  if ($quiet.IsPresent) { $progress = -not $quiet }
  else { $progress = $true }

  $loc = Get-HPPrivateItemUrl -Number $no -Ext "exe" -url $url
  $target = $null
  $root = $null

  if ($friendlyName.IsPresent -or $action) {
    # get SoftPaq metadata
    try { $root = Get-SoftpaqMetadata $no -url $url -maxRetries $maxRetries }
    catch {
      if ($progress -eq $true) {
        Write-Host -ForegroundColor Magenta "(Warning) Could not retrieve CVA file metadata for sp$no."
        Write-Host -ForegroundColor Magenta $_.Exception.Message
      }
    }
  }

  # build the filename
  if (!$saveAs) {
    if ($friendlyName.IsPresent)
    {
      Write-Verbose "Need to get CVA data to determine Friendly Name for SoftPaq file"
      $target = getfriendlyFileName -Number $no -info $root -Verbose:$VerbosePreference
      $target = "$target.exe"
    }

    else { $target = "sp$no.exe" }
  }
  else { $target = $saveAs }

  if($DestinationPath){
    # remove trailing backslashes in DestinationPath because SoftPaqs do not allow execution with trailing backslashes
    $DestinationPath = $DestinationPath.TrimEnd('\')

    # use DestinationPath if given for downloads 
    $targetFile = Join-Path -Path $DestinationPath -ChildPath $target
  }
  else {
    $targetFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($target)
  }

  Write-Verbose "TargetFile: $targetFile"

  try
  {
    Invoke-HPPrivateDownloadFile -url $loc -Target $targetFile -progress $progress -NoClobber $overwrite -Verbose:$VerbosePreference -maxRetries $maxRetries
  }
  catch
  {
    Write-Host -ForegroundColor Magenta "(Warning) Could not retrieve $loc."
    Write-Host -ForegroundColor Magenta $_.Exception.Message
    throw $_.Exception
  }

  # check digital signatures
  $signed = Get-HPPrivateCheckSignature -File $targetFile -Verbose:$VerbosePreference -Progress:(-not $Quiet.IsPresent)

  if ($signed -eq $false) {
    switch ($keepInvalid) {
      $true {
        if ($progress -eq $true) {
          Write-Host -ForegroundColor Magenta "(Warning): File $targetFile has an invalid or missing signature"
          return
        }
      }
      $false {
        Invoke-HPPrivateSafeRemove -Path $targetFile -Verbose:$VerbosePreference
        throw [System.BadImageFormatException]"File $targetFile has invalid or missing signature and will be deleted."
        return
      }
    }
  }
  else {
    if ($progress -eq $true) {
      Write-Verbose "Digital signature is valid."
    }
  }

  if ($Extract.IsPresent) {
    if (!$DestinationPath) {
      # by default, the -replace operator is case-insensitive 
      $DestinationPath = Join-Path -Path $(Get-Location) -ChildPath ($target -replace ".exe","")
    }
    if ($DestinationPath -match [regex]::Escape([System.Environment]::SystemDirectory)) {
      throw 'Windows System32 is not a valid destination path.'
    }

    $tempWorkingPath = $(Get-HPPrivateTempPath)
    $workingPath = Join-Path -Path $tempWorkingPath -ChildPath $target
    Write-Verbose "Copying downloaded SoftPaq to temporary working directory $workingPath"
    
    if(-not (Test-Path -Path $tempWorkingPath)){
      Write-Verbose "Part of the temporary working directory does not exist. Creating $tempWorkingPath before copying" 
      New-Item -Path $tempWorkingPath -ItemType "Directory" -Force | Out-Null 
    }

    Copy-Item -Path $targetFile -Destination $workingPath -Force

    # calling Invoke-PostDownloadSoftpaqAction with action as Extract even though Action parameter is limited to Install and SilentInstall 
    Invoke-PostDownloadSoftpaqAction -downloadedFile $workingPath -Action "extract" -Number $number -info $root -Destination $DestinationPath -Verbose:$VerbosePreference
    Write-Verbose "Removing SoftPaq from the temporary working directory $workingPath"
    Remove-Item -Path $workingPath -Force
  }

  # perform requested action
  if ($action)
  {
    Invoke-PostDownloadSoftpaqAction -downloadedFile $targetFile -Action $action -Number $number -info $root -Destination $DestinationPath -Verbose:$VerbosePreference
  }
}

<#
.SYNOPSIS
  Downloads the metadata of a SoftPaq metadata in CVA file format from ftp.hp.com or from a specified alternate server with additional configuration capabilities in comparison to the Get-SoftPaqMetadata command

.DESCRIPTION
  This command downloads the metadata of a SoftPaq metadata in CVA file format from ftp.hp.com or from a specified alternate server with additional configuration capabilities in comparison to the Get-SoftPaqMetadata command.

  The additional configuration capabilities are detailed using the following parameters:
  - SaveAs
  - FriendlyName
  - Quiet
  - Overwrite 

  Please note that this command calls the Get-SoftPaqMetadata command if the -FriendlyName parameter is specified. 

.PARAMETER Number
  Specifies the SoftPaq number for which to retrieve the metadata. Do not include any prefixes like 'SP' or any extensions like '.exe'. Please specify the SoftPaq number only.

.PARAMETER SaveAs
  Specifies a name for the saved SoftPaq metadata. Otherwise the name is inferred based on the remote name or on the metadata if the -FriendlyName parameter is specified.

.PARAMETER FriendlyName
  Specifies a friendly name for the downloaded SoftPaq based on the SoftPaq number and title

.PARAMETER Quiet
  If specified, this command will suppress non-essential messages during execution. 

.PARAMETER Overwrite
  Specifies the the overwrite behavior.
  The possible values include:
  "no" = (default if this parameter is not specified) do not overwrite existing files
  "yes" = force overwrite
  "skip" = skip existing files without any error

.PARAMETER MaxRetries
  Specifies the maximum number of retries allowed to obtain an exclusive lock to downloaded files. This is relevant only when files are downloaded into a shared directory and multiple processes may be reading or writing from the same location.

  Current default value is 10 retries, and each retry includes a 30 second pause, which means the maximum time the default value will wait for an exclusive logs is 300 seconds or 5 minutes.

.PARAMETER url
  Specifies an alternate location for the SoftPaq URL. This URL must be HTTPS. The SoftPaq CVAs are expected to be at the location pointed to by this URL. If not specified, ftp.hp.com is used via HTTPS protocol.

.EXAMPLE
  Get-SoftpaqMetadataFile -Number 1234

.LINK
  [Get-SoftpaqMetadata](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqMetadata)

.LINK
  [Get-Softpaq](https://developers.hp.com/hp-client-management/doc/Get-Softpaq)

.LINK
  [Get-SoftpaqList](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqList)

.LINK
  [Out-SoftpaqField](https://developers.hp.com/hp-client-management/doc/Out-SoftpaqField)

.LINK
  [Clear-SoftpaqCache](https://developers.hp.com/hp-client-management/doc/Clear-SoftpaqCache)

#>
function Get-SoftpaqMetadataFile {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-SoftpaqMetadataFile")]
  param(
    [ValidatePattern('^([Ss][Pp])*([0-9]{3,9})((\.[Ee][Xx][Ee]|\.[Cc][Vv][Aa])*)$')]
    [Parameter(Position = 0,Mandatory = $true)]
    [string]$Number,
    [Parameter(Position = 1,Mandatory = $false)]
    [string]$SaveAs,
    [Parameter(Position = 2,Mandatory = $false)]
    [switch]$FriendlyName,
    [Parameter(Position = 3,Mandatory = $false)]
    [switch]$Quiet,
    [ValidateSet("No","Yes","Skip")]
    [Parameter(Position = 4,Mandatory = $false)]
    [string]$Overwrite = "No",
    [Parameter(Position = 5,Mandatory = $false)]
    [string]$Url,
    [Parameter(Position = 6,Mandatory = $false)]
    [int]$MaxRetries = 0
  )

    # only allow https or file paths with or without file:// URL prefix
  if ($Url -and -not ($Url.StartsWith("https://",$true,$null) -or [System.IO.Directory]::Exists($Url) -or $Url.StartsWith("file://",$true,$null))) {
    throw [System.ArgumentException]"Only HTTPS or valid existing directory paths are supported."
  }

  [System.Net.ServicePointManager]::SecurityProtocol = Get-HPPrivateAllowedHttpsProtocols
  $no = [int]$number.ToLower().TrimStart("sp").trimend(".exe").trimend('cva')

  if ($quiet.IsPresent) { $progress = -not $quiet }
  else { $progress = $true }

  $loc = Get-HPPrivateItemUrl -Number $no -Ext "cva" -url $url

  $target = $null

  # get SoftPaq metadata. We don't need this step unless we get friendly name
  if ($friendlyName.IsPresent) {
    Write-Verbose "Need to get CVA data to determine Friendly Name for CVA file"
    try { $root = Get-SoftpaqMetadata $number -url $url -maxRetries $maxRetries }
    catch {
      if ($progress -eq $true) {
        Write-Host -ForegroundColor Magenta "(Warning) Could not retrieve CVA file metadata"
        Write-Host -ForegroundColor Magenta $_.Exception.Message
      }
      $root = $null
    }
  }

  # build the filename
  if (!$saveAs) {
    if ($friendlyName.IsPresent) {
      Write-Verbose "Need to get CVA data to determine Friendly Name for CVA file"
      $target = getfriendlyFileName -Number $no -info $root -Verbose:$VerbosePreference
      $target = "$target.cva"
    }
    else { $target = "sp$no.cva" }
  }
  else { $target = $saveAs }

  # download the file
  $targetFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($target)
  Invoke-HPPrivateDownloadFile -url $loc -Target $targetFile -progress $progress -NoClobber $overwrite -Verbose:$VerbosePreference -maxRetries $maxRetries -skipSignatureCheck
}

<#
.SYNOPSIS
  Extracts the information of a specified field from the SoftPaq metadata

.DESCRIPTION
  This command extracts the information of a specified field from the SoftPaq metadata. The currently supported fields are:

  - Description
  - Install 
  - Number
  - PlatformIDs
  - Platforms
  - SilentInstall
  - SoftPaqSHA256
  - Title
  - Version
  

.PARAMETER Field
  Specifies the field to filter the SoftPaq metadata on. Choose from the following values: 
  - Install
  - SilentInstall
  - Title
  - Description
  - Number
  - Platforms
  - PlatformIDs
  - SoftPaqSHA256
  - Version

.PARAMETER InputObject
  Specifies the root node of the SoftPaq metadata to extract information from 

.EXAMPLE
  $mysoftpaq | Out-SoftpaqField -Field Title

.LINK
  [Get-SoftpaqMetadata](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqMetadata)

.LINK
  [Get-Softpaq](https://developers.hp.com/hp-client-management/doc/Get-Softpaq)

.LINK
  [Get-SoftpaqList](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqList)

.LINK
  [Get-Softpaq](https://developers.hp.com/hp-client-management/doc/Get-Softpaq)

.LINK
  [Clear-SoftpaqCache](https://developers.hp.com/hp-client-management/doc/Clear-SoftpaqCache)
#>
function Out-SoftpaqField {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Out-SoftpaqField")]
  param(
    [ValidateSet("Install","SilentInstall","Title","Description","Number","Platforms","PlatformIDs","SoftPaqSHA256","Version")]
    [Parameter(Mandatory = $True)]
    [string]$Field,

    [ValidateNotNullOrEmpty()]
    [Parameter(ValueFromPipeline = $True,Mandatory = $True)]
    [Alias('In')]
    $InputObject
  )

  begin {
    if (!$mapper.contains($field)) {
      throw [InvalidOperationException]"Field '$field' is not supported as a filter"
    }
  }
  process
  {
    $result = descendNodesAndGet $InputObject -Field $field
    if ($mapper[$field] -match "%KeyValues\(.*\)$") {

      $pattern = $mapper[$field] -match "\((.*)\)"
      if ($pattern[0]) {

        # Need to narrow it down to PlatformIDs otherwise Platforms will be shown in UpperCase too. 
        if ($Field -eq "PlatformIDs") {
          $result = $result[$result.keys -match $matches[1]].ToUpper() | Get-Unique
          return $result -replace "^0X",''
        }
        else {
          return $result[$result.keys -match $matches[1]] | Get-Unique
        }
      }
    }
    return $result
  }
  end {}
}

<#
.SYNOPSIS
  Clears the cache used for downloading SoftPaq database files 

.DESCRIPTION

  This command clears the cache used for downloading SoftPaq database files.

  This command is not needed in normal operations as the cache does not grow significantly over time and is also cleared when normal operations flush the user's temporary directory.

  This command is only intended for debugging purposes.



.EXAMPLE
    Clear-SoftpaqCache

.PARAMETER cacheDir
  Specifies a custom location for caching data files. If not specified, the user-specific TEMP directory is used.


.LINK
  [Get-SoftpaqMetadata](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqMetadata)

.LINK
  [Get-Softpaq](https://developers.hp.com/hp-client-management/doc/Get-Softpaq)

.LINK
  [Get-SoftpaqList](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqList)

.LINK
  [Get-Softpaq](https://developers.hp.com/hp-client-management/doc/Get-Softpaq)

.LINK
  [Out-SoftpaqField](https://developers.hp.com/hp-client-management/doc/Out-SoftpaqField)

.NOTES
    This command removes the cached files from the user temporary directory. It cannot be used to clear the cache
  when the data files are stored inside a repository structure. Custom cache locations (other than the default)
  must be specified via the cacheDir folder. 

#>
function Clear-SoftpaqCache {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Clear-SoftpaqCache")]
  param(
    [Parameter(Mandatory = $false)]
    [System.IO.DirectoryInfo]$CacheDir
  )
  $cacheDir = Get-HPPrivateCacheDirPath ($cacheDir)
  Invoke-HPPrivateSafeRemove -Path $cacheDir -Recurse
}

<#
.SYNOPSIS
  Retrieves a list of SoftPaqs for the current platform or a specified platform ID

.DESCRIPTION
  This command retrieves a list of SoftPaqs for the current platform or a specified platform ID.
  Note that this command is not supported in WinPE.

.PARAMETER Platform
  Specifies a platform ID to retrieve a list of associated SoftPaqs. If not specified, the current platform ID is used.

.PARAMETER Bitness
  Specifies the platform bitness (32 or 64 or arm64). If not specified, the current platform bitness is used.

.PARAMETER Os
  Specifies an OS for this command to filter based on. The value must be 'win10' or 'win11'. If not specified, the current platform OS is used.

.PARAMETER OsVer
  Specifies an OS version for this command to filter based on. The value must be a string value specifying the target OS Version (e.g. '1809', '1903', '1909', '2004', '2009', '21H1', '21H2', '22H2', '23H2', '24H2', etc). If this parameter is not specified, the current operating system version is used.

.PARAMETER Category
  Specifies a category of SoftPaqs for this command to filter based on. The value must be one (or more) of the following values: 
  - Bios
  - Firmware
  - Driver
  - Software
  - OS
  - Manageability
  - Diagnostic
  - Utility
  - Driverpack
  - Dock
  - UWPPack

.PARAMETER ReleaseType 
  Specifies a release type for this command to filter based on. The value must be one (or more) of the following values:
  - Critical
  - Recommended
  - Routine

  If this parameter is not specified, all release types are included.

.PARAMETER ReferenceUrl
  Specifies an alternate location for the HP Image Assistant (HPIA) Reference files. If passing a file path, the path can be relative path or absolute path. If passing a URL to this parameter, the URL must be a HTTPS URL. The HPIA Reference files are expected to be inside a directory named after the platform ID pointed to by this parameter. 
  For example, if you want to point to system ID 83b2, OS Win10, and OSVer 2009 reference files, the Get-SoftpaqList command will try to find them in: $ReferenceUrl/83b2/83b2_64_10.0.2009.cab
  If not specified, 'https://hpia.hpcloud.hp.com/ref/' is used by default, and fallback is set to 'https://ftp.hp.com/pub/caps-softpaq/cmit/imagepal/ref/'.

.PARAMETER SoftpaqUrl
  Specifies an alternate location for the SoftPaq URL. This URL must be HTTPS. The SoftPaqs are expected to be at the location pointed to by this URL. If not specified, ftp.hp.com is used via HTTPS protocol.

.PARAMETER Quiet
  If specified, this command will suppress non-essential messages during execution. 

.PARAMETER Download 
  If specified, this command will download matching SoftPaqs. 

.PARAMETER DownloadMetadata
  If specified, this command will download CVA files (metadata) for matching SoftPaqs. 

.PARAMETER DownloadNotes
  If specified, this command will download note files (human readable info files) for matching SoftPaqs. 

.PARAMETER DownloadDirectory
  Specifies a directory for the downloaded files

.PARAMETER FriendlyName 
  If specified, this command will retrieve the SoftPaq metadata and create a friendly file name based on the SoftPaq title. Applies if the Download parameter is specified.

.PARAMETER Overwrite
  Specifies the the overwrite behavior. The value must be one of the following values:
  - no: (default if this parameter is not specified) do not overwrite existing files
  - yes: force overwrite
  - skip: skip existing files without any error

.PARAMETER Format
  Specifies the format of the output results. The value must be one of the following values:
  - Json
  - XML
  - CSV
  
  If not specified, results are returned as PowerShell objects.

.PARAMETER Characteristic
  Specifies characteristics for this command to filter based on. The value must be one (or more) of the following values:
  - SSM
  - DPB
  - UWP 

.PARAMETER CacheDir
  Specifies a location for caching data files. If not specified, the user-specific TEMP directory is used.

.PARAMETER MaxRetries
  Specifies the maximum number of retries allowed to obtain an exclusive lock to downloaded files. This is relevant only when files are downloaded into a shared directory and multiple processes may be reading or writing from the same location.

  The current default value is 10 retries, and each retry includes a 30 second pause, which means the maximum time the default value will wait for an exclusive logs is 300 seconds or 5 minutes.

.PARAMETER PreferLTSC
  If specified and if the data file exists, this command retrieves the Long-Term Servicing Branch/Long-Term Servicing Channel (LTSB/LTSC) Reference file for the specified platform ID. If the data file does not exist, this command uses the regular Reference file for the specified platform.

.PARAMETER AddHttps
  If specified, this command prepends the https tag to the url, ReleaseNotes, and Metadata SoftPaq attributes.

.EXAMPLE
  Get-SoftpaqList -Download

.EXAMPLE
  Get-SoftpaqList -Bitness 64 -Os win10 -OsVer 1903

.EXAMPLE
  Get-SoftpaqList -Platform 83b2 -Os win10 -OsVer "21H1"

.EXAMPLE
  Get-SoftpaqList -Platform 8444 -Category Diagnostic -Format json

.EXAMPLE
  Get-SoftpaqList -Category Driverpack

.EXAMPLE
  Get-SoftpaqList -ReleaseType Critical -Characteristic SSM

.EXAMPLE
  Get-SoftpaqList -Platform 83b2 -Category Dock,Firmware -ReleaseType Routine,Critical

.EXAMPLE 
  Get-SoftpaqList -Platform 2216 -Category Driverpack -Os win10 -OsVer 1607 -PreferLTSC

.LINK
  [Get-SoftpaqMetadata](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqMetadata)

.LINK
  [Get-Softpaq](https://developers.hp.com/hp-client-management/doc/Get-Softpaq)

.LINK
  [Clear-SoftpaqCache](https://developers.hp.com/hp-client-management/doc/Clear-SoftpaqCache)

.LINK
  [Get-Softpaq](https://developers.hp.com/hp-client-management/doc/Get-Softpaq)

.LINK
  [Out-SoftpaqField](https://developers.hp.com/hp-client-management/doc/Out-SoftpaqField)

.NOTES
  The response is a record set composed of zero or more SoftPaq records. The definition of a record is as follows:

  | Field         | Description |
  |---------------|-------------|
  | Id            | The SoftPaq identifier |
  | Name          | The SoftPaq name (title) |
  | Category      | The SoftPaq category |
  | Version       | The SoftPaq version |
  | Vendor        | The author of the SoftPaq |
  | ReleaseType   | The SoftPaq release type |
  | SSM           | This flag indicates this SoftPaq support unattended silent install |
  | DPB           | This flag indicates this SoftPaq is included in driver pack builds |
  | Url           | The SoftPaq download URL |
  | ReleaseNotes  | The URL to a human-readable rendering of the SoftPaq release notes |
  | Metadata      | The URL to the SoftPaq metadata (CVA) file |
  | Size          | The SoftPaq size, in bytes |
  | ReleaseDate   | The date the SoftPaq was published |
  | UWP           | (where available) This flag indicates this SoftPaq contains Universal Windows Platform applications |

#>
function Get-SoftpaqList {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-SoftpaqList",DefaultParameterSetName = "ViewParams")]
  param(

    [ValidatePattern("^[a-fA-F0-9]{4}$")]
    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 0,Mandatory = $false,ParameterSetName = "ViewParams")] [string]$Platform,

    [ValidateSet("32","64", "arm64")]
    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 1,Mandatory = $false,ParameterSetName = "ViewParams")] [string]$Bitness,

    [ValidateSet($null,"win7","win8","win8.1","win81","win10","win11")]
    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 2,Mandatory = $false,ParameterSetName = "ViewParams")] [string]$Os,

    [ValidateSet("1809","1903","1909","2004","2009","21H1","21H2","22H2", "23H2", "24H2")]
    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 3,Mandatory = $false,ParameterSetName = "ViewParams")] [string]$OsVer,

    [Parameter(ParameterSetName = "DownloadParams")]
    [Alias('Url')]
    [Parameter(Position = 4,Mandatory = $false,ParameterSetName = "ViewParams")] [string]$ReferenceUrl = "https://hpia.hpcloud.hp.com/ref",

    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 5,Mandatory = $false,ParameterSetName = "ViewParams")] [switch]$Quiet,

    [Parameter(ParameterSetName = "DownloadParams")]
    [ValidateSet("XML","Json","CSV")]
    [Parameter(Position = 6,ParameterSetName = "ViewParams")] [string]$Format,

    [Parameter(Position = 7,ParameterSetName = "DownloadParams")] [string]$DownloadDirectory,

    [Alias("downloadSoftpaq","downloadPackage")]
    [Parameter(Position = 8,ParameterSetName = "DownloadParams")] [switch]$Download,

    [Alias("downloadCva")]
    [Parameter(Position = 9,ParameterSetName = "DownloadParams")] [switch]$DownloadMetadata,
    [Parameter(Position = 10,ParameterSetName = "DownloadParams")] [switch]$DownloadNotes,
    [Parameter(Position = 11,ParameterSetName = "DownloadParams")] [switch]$FriendlyName,

    [ValidateSet("No","Yes","Skip")]
    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 12,Mandatory = $false,ParameterSetName = "ViewParams")] [string]$Overwrite = "No",


    [ValidateSet("BIOS","Firmware","Driver","Software","OS","Manageability","Diagnostic","Utility","Driverpack","Dock","UWPPack")]
    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 13,ParameterSetName = "ViewParams")] [string[]]$Category = $null,


    [ValidateSet("Critical","Recommended","Routine")]
    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 14,ParameterSetName = "ViewParams")] [string[]]$ReleaseType = $null,


    [ValidateSet("SSM","DPB","UWP")]
    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 15,ParameterSetName = "ViewParams")] [string[]]$Characteristic = $null,


    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 16,ParameterSetName = "ViewParams")] [System.IO.DirectoryInfo]$CacheDir,

    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 17,Mandatory = $false,ParameterSetName = "ViewParams")] [int]$MaxRetries = 0,

    [Alias("PreferLTSB")]
    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 18,Mandatory = $false,ParameterSetName = "ViewParams")] [switch]$PreferLTSC,

    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 19,Mandatory = $false,ParameterSetName = "ViewParams")] [string]$SoftpaqUrl,

    [Parameter(ParameterSetName = "DownloadParams")]
    [Parameter(Position = 20,Mandatory = $false,ParameterSetName = "ViewParams")] [switch]$AddHttps
  )

  if (Test-WinPE) {
    throw [NotSupportedException]"This operation is not supported in WinPE"
  }

  [System.Net.ServicePointManager]::SecurityProtocol = Get-HPPrivateAllowedHttpsProtocols
  $ver = ""
  $progress = $true
  $cacheDir = Get-HPPrivateCacheDirPath ($cacheDir)

  if ($quiet.IsPresent) { $progress = -not $quiet }
  if (-not $platform) { $platform = Get-HPDeviceProductID }
  $platform = $platform.ToLower()
  if ($OsVer) { $OsVer = $OsVer.ToLower() }

  if (!$bitness) {
    $bitness = Get-HPPrivateCurrentOsBitness
  }
  if (!$os) {
    $os = Get-HPPrivateCurrentOs
  }


  if (([System.Environment]::OSVersion.Version.Major -eq 10) -and $OsVer) {

    try {
      # try converting OsVer to int
      $OSVer = [int]$OsVer

      if ($OSVer -gt 2009 -or $OSVer -lt 1507) {
        throw "Unsupported operating system version"
      }
    }
    catch {
      if (!($OSVer -match '[0-9]{2}[hH][0-9]')) {
        throw "Unsupported operating system version"
      }
    }
  }

  # determine OSVer for Win10 if OSVer is not passed
  if (([System.Environment]::OSVersion.Version.Major -eq 10) -and (!$osver))
  {
    Write-Verbose "need to determine OSVer"
    $osver = GetCurrentOSVer
  }

  switch ($os)
  {
    "win10" { $ver = "10.0." + $osver.ToString() }
    "win11" { $ver = "11.0." + $osver.ToString() }
    "win81" { $ver = "6.3" }
    "win8.1" { $ver = "6.3" }
    "win8" { $ver = "6.2" }
    "win7" { $ver = "6.1" }
    default { throw [NotSupportedException]"Unsupported operating system: " + $_ }
  }

  if (-not $ReferenceUrl.EndsWith('/')) {
    $ReferenceUrl = $ReferenceUrl + "/"
  }

  # Fallback to FTP only if ReferenceUrl is the default, and not when a custom ReferenceUrl is specified
  if ($ReferenceUrl -eq 'https://hpia.hpcloud.hp.com/ref/') {
    $referenceFallbackUrL = 'https://ftp.hp.com/pub/caps-softpaq/cmit/imagepal/ref/'
  }
  else {
    $referenceFallbackUrL = ''
  }

  $fn = "$($platform)_$($bitness)_$($ver)"
  #Write-Host -ForegroundColor Magenta $fn
  $result = $null
  $LTSCExists = $false

  if ($PreferLTSC.IsPresent) {
    $qurl = "$($ReferenceUrl)$platform/$fn.e.cab"
    $qfile = Get-HPPrivateTemporaryFileName -FileName "$fn.e.cab" -cacheDir $cacheDir
    $downloadedFile = "$qfile.dir\$fn.e.xml"
    $try_on_ftp = $false
    try {
      $result = Test-HPPrivateIsDownloadNeeded -url $qurl -File $qfile -Verbose:$VerbosePreference
      if ($result[1] -eq $true) {
        Write-Verbose "Trying to download $qurl from AWS Server..."
      }
      $LTSCExists = $true
    }
    catch {
      Write-Verbose "HTTPS request to $qurl failed: $($_.Exception.Message)"
      if ($referenceFallbackUrL) {
        $try_on_ftp = $true
      }
    }

    if ($try_on_ftp) {
      try {
        Write-Verbose "$qurl not found on AWS Server. Trying to download it from FTP Server..."
        $qurl = "$($ReferenceFallbackUrl)$platform/$fn.e.cab"
        $result = Test-HPPrivateIsDownloadNeeded -url $qurl -File $qfile -Verbose:$VerbosePreference
        if ($result[1] -eq $true) {
          $LTSCExists = $true
        }
      }
      catch {
        Write-Verbose "HTTPS request to $qurl failed: $($_.Exception.Message)"
        if (-not $quiet -or $result[1] -eq $false) {
          Write-Host -ForegroundColor Magenta "LTSB/LTSC data file doesn't exists for platform $platform ($os $osver)"
          Write-Host -ForegroundColor Cyan "Getting the regular (non-LTSB/LTSC) data file for this platform"
        }
      }
    }
  }

  # LTSB(C) file doesn't exists, fall back to regular Ref file
  if ((-not $PreferLTSC.IsPresent) -or ($PreferLTSC.IsPresent -and ($LTSCExists -eq $false))) {
    $qurl = "$($ReferenceUrl)$platform/$fn.cab"
    $qfile = Get-HPPrivateTemporaryFileName -FileName "$fn.cab" -cacheDir $cacheDir
    $downloadedFile = "$qfile.dir\$fn.xml"
    $try_on_ftp = $false
    try {
      $result = Test-HPPrivateIsDownloadNeeded -url $qurl -File $qfile -Verbose:$VerbosePreference
      if ($result[1] -eq $true) {
        Write-Verbose "Trying to download $qurl from AWS Server..."
      }
    }
    catch {
      Write-Host "HTTPS request to $qurl failed: $($_.Exception.Message)"
      if ($referenceFallbackUrL) {
        $try_on_ftp = $true
      }
      else {
        throw [System.Net.WebException]"Could not find data file $qurl for platform $platform."
      }
    }

    if ($try_on_ftp) {
      try {
        Write-Verbose "$qurl not found on AWS Server. Trying to download it from FTP Server..."
        $qurl = "$($ReferenceFallbackUrl)$platform/$fn.cab"
        $result = Test-HPPrivateIsDownloadNeeded -url $qurl -File $qfile -Verbose:$VerbosePreference
      }
      catch {
        Write-Host "HTTPS request to $qurl failed: $($_.Exception.Message)"
        if (-not $quiet -or $result[1] -eq $false) {
          Write-Host -ForegroundColor Magenta $_.Exception.Message
        }
        throw [System.Net.WebException]"Could not find data file $qurl for platform $platform."
      }
    }
  }

  if ($result -and $result[1] -eq $true) {
    Write-Verbose "Cleaning cached data and downloading the data file."
    Invoke-HPPrivateDeleteCachedItem -cab $qfile
    Invoke-HPPrivateDownloadFile -url $qurl -Target $qfile -progress $progress -NoClobber $overwrite -Verbose:$VerbosePreference -maxRetries $maxRetries
    (Get-Item $qfile).CreationTime = ($result[0])
    (Get-Item $qfile).LastWriteTime = ($result[0])
  }

  # Need to make sure that the expanded data file exists and is not corrupted. 
  # Otherwise, expand the cab file.
  if (-not (Test-Path $downloadedFile) -or (-not (Test-HPPrivateIsValidXmlFile -File $downloadedFile)))
  {
    Write-Verbose "Extracting the data file and looking for $downloadedFile."
    $file = Invoke-HPPrivateExpandCAB -cab $qfile -expectedFile $downloadedFile -Verbose:$VerbosePreference
  }

  Write-Verbose "Reading XML document  $downloadedFile"
  # Default encoding for PS5.1 is Default meaning the encoding that correpsonds to the system's active code page
  # Default encoding for PS7.3 is utf8NoBOM 
  [xml]$data = Get-Content $downloadedFile -Encoding UTF8
  Write-Verbose "Parsing the document"

  $d = Select-Xml -Xml $data -XPath "//ImagePal/Solutions/UpdateInfo"

  $results = $d.Node | ForEach-Object {
    if (($null -ne $releaseType) -and ($_.ReleaseType -notin $releaseType)) { return }
    if (-not (matchCategory -cat $_.Category -allowed $category -EQ $true)) { return }
    if ("ContentTypes" -in $_.PSObject.Properties.Name) { $ContentTypes = $_.ContentTypes } else { $ContentTypes = $null }
    if (($null -ne $characteristic) -and (-not (matchAllCharacteristic $characteristic -SSM $_.SSMCompliant -DPB $_.DPBCompliant -UWP $ContentTypes))) { return }
    if ($AddHttps.IsPresent) {
      $objUrl = "https://$($_.url)"
      $objReleaseNotes = "https://$($_.ReleaseNotesUrl)"
      $objMetadata = "https://$($_.CvaUrl)"
    }
    else {
      $objUrl = $_.url
      $objReleaseNotes = $_.ReleaseNotesUrl
      $objMetadata = $_.CvaUrl
    }

    $pso = [pscustomobject]@{
      id = $_.id
      Name = $_.Name
      Category = $_.Category
      Version = $_.Version.TrimStart("0.")
      Vendor = $_.Vendor
      ReleaseType = $_.ReleaseType
      SSM = $_.SSMCompliant
      DPB = $_.DPBCompliant
      url = $objUrl
      ReleaseNotes = $objReleaseNotes
      Metadata = $objMetadata
      Size = $_.Size
      ReleaseDate = $_.DateReleased
      UWP = $(if ("ContentTypes" -in $_.PSObject.Properties.Name) { $true } else { $false })
    }
    $pso



    if ($download.IsPresent) {
      [int]$id = $pso.id.ToLower().Replace("sp","")
      if ($friendlyName.IsPresent) {
        Write-Verbose "Need to get CVA data to determine Friendly Name for download file"
        $target = getfriendlyFileName -Number $pso.id.ToLower().TrimStart("sp") -From $pso.Name -Verbose:$VerbosePreference
      }
      else { $target = $pso.id }

      if ($downloadDirectory) { $target = "$downloadDirectory\$target" }
      else {
        $cwd = Convert-Path .
        $target = "$cwd\$target"
      }

      if ($downloadMetadata.IsPresent)
      {
        $loc = Get-HPPrivateItemUrl -Number $Id -Ext "cva" -url $SoftpaqUrl
        Invoke-HPPrivateDownloadFile -url $loc -Target "$target.cva" -progress $progress -NoClobber $overwrite -Verbose:$VerbosePreference -skipSignatureCheck -maxRetries $maxRetries
      }

      $loc = Get-HPPrivateItemUrl -Number $Id -Ext "exe" -url $SoftpaqUrl

      Invoke-HPPrivateDownloadFile -url $loc -Target "$target.exe" -progress $progress -NoClobber $overwrite -Verbose:$VerbosePreference -maxRetries $maxRetries

      if ($downloadNotes.IsPresent)
      {
        $loc = Get-HPPrivateItemUrl -Number $Id -Ext "html" -url $SoftpaqUrl
        Invoke-HPPrivateDownloadFile -url $loc -Target "$target.htm" -progress $progress -NoClobber $overwrite -Verbose:$VerbosePreference -skipSignatureCheck -maxRetries $maxRetries
      }
    }
  }

  $result = $results | Select-Object * -Unique
  switch ($format)
  {
    "xml" { $result | ConvertTo-Xml -As String }
    "json" { $result | ConvertTo-Json }
    "csv" { $result | ConvertTo-Csv -NoTypeInformation }
    default { return $result }
  }
}

<#
.SYNOPSIS
  Retrieves the latest version, HPIA download URL, and SoftPaq URL of HP Image Assistant ([HPIA](https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA.html))

.DESCRIPTION
  This command returns the latest version of HPIA returned as a System.Version object, the HPIA download page, and the SoftPaq download URL.

.EXAMPLE
  Get-HPImageAssistantUpdateInfo 

.LINK
  [Install-HPImageAssistant](https://developers.hp.com/hp-client-management/doc/Install-HPImageAssistant)

#>
function Get-HPImageAssistantUpdateInfo {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-HPImageAssistantUpdateInfo ")]
  param()

  $cacheDir = Get-HPPrivateCacheDirPath -Verbose:$VerbosePreference

  $source = "https://hpia.hpcloud.hp.com/HPIAMsg.cab"
  $fallbackSource = "https://ftp.hp.com/pub/caps-softpaq/cmit/imagepal/HPIAMsg.cab"

  $sourceFile = Get-HPPrivateTemporaryFileName -FileName "HPIAMsg.cab" -cacheDir $cacheDir
  $downloadedFile = "$sourceFile.dir\HPIAMsg.xml"

  $try_on_ftp = $false
  try {
    $result = Test-HPPrivateIsDownloadNeeded -url $source -File $sourceFile -Verbose:$VerbosePreference
    if ($result[1] -eq $true) {
      Write-Verbose "Trying to download $source from AWS Server..."
    }
  }
  catch {
    $try_on_ftp = $true
  }

  if ($try_on_ftp) {
    try {
      Write-Verbose "$source not found on AWS Server. Trying to download it from FTP Server..."
      $source = $fallbackSource
      $result = Test-HPPrivateIsDownloadNeeded -url $source -File $sourceFile -Verbose:$VerbosePreference
      if ($result[1] -eq $true) {
        Write-Verbose "Trying to download $source from FTP Server..."
      }
    }
    catch {
      if ($result[1] -eq $false) {
        Write-Host -ForegroundColor Magenta "data file not found"
      }
    }
  }

  if ($result[1] -eq $true) {
    Write-Verbose "Cleaning cached data and downloading the data file."
    Invoke-HPPrivateDeleteCachedItem -cab $sourceFile
    Invoke-HPPrivateDownloadFile -url $source -Target $sourceFile -Verbose:$VerbosePreference
  }

  Write-Verbose "Downloaded file is : $downloadedFile"
  # Need to make sure that the expanded data file exists and is not corrupted. 
  # Otherwise, expand the cab file.
  if (-not (Test-Path $downloadedFile) -or (-not (Test-HPPrivateIsValidXmlFile -File $downloadedFile)))
  {
    Write-Verbose "Extracting the data file, looking for $downloadedFile."
    $file = Invoke-HPPrivateExpandCAB -cab $sourceFile -expectedFile $downloadedFile
    Write-Verbose $file
  }

  Write-Verbose "Reading XML document  $downloadedFile"
  # Default encoding for PS5.1 is Default meaning the encoding that correpsonds to the system's active code page
  # Default encoding for PS7.3 is utf8NoBOM 
  [xml]$data = Get-Content $downloadedFile -Encoding UTF8
  Write-Verbose "Parsing the document"

  # Getting the SoftPaq information
  $SoftpaqVersion = $data.ImagePal.HPIALatest.Version
  $SoftpaqUrl = $data.ImagePal.HPIALatest.SoftpaqURL
  $DownloadPage = $data.ImagePal.HPIALatest.DownloadPage

  # change SoftpaqVersion from a string to a System.Version object
  $SoftpaqVersion = [System.Version]$SoftpaqVersion

  $result = [ordered]@{
    Version = $SoftpaqVersion
    DownloadPage = $DownloadPage
    SoftpaqURL = $SoftpaqUrl
  }

  return $result
  
}

<#
.SYNOPSIS
  Installs the latest version of HP Image Assistant ([HPIA](https://ftp.hp.com/pub/caps-softpaq/cmit/HPIA.html))

.DESCRIPTION
  This command finds the latest version of HPIA and downloads the SoftPaq. If the Extract parameter is not used, the SoftPaq is only downloaded and not executed.

.PARAMETER Extract
  If specified, this command extracts SoftPaq content to a specified destination folder. Specify the destination folder with the DestinationPath parameter. 

  If the DestinationPath parameter is not specified, the files are extracted into a new sub-folder relative to the downloaded SoftPaq executable.

.PARAMETER DestinationPath
  Specifies the path to the folder in which you want to save downloaded and/or extracted files. Do not specify a file name or file name extension. 

  If not specified, the executable is downloaded to the current folder, and the files are extracted into a new sub-folder relative to the downloaded executable.

.PARAMETER Source
  This parameter is currently reserved for internal use only.

.PARAMETER CacheDir
  Specifies a custom location for caching data files. If not specified, the user-specific TEMP directory is used.

.PARAMETER MaxRetries
  Specifies the maximum number of retries allowed to obtain an exclusive lock to downloaded files. This is relevant only when files are downloaded into a shared directory and multiple processes may be reading or writing from the same location.

  Current default value is 10 retries, and each retry includes a 30 second pause, which means the maximum time the default value will wait for an exclusive logs is 300 seconds or 5 minutes.

.PARAMETER Quiet
  If specified, this command will suppress non-essential messages during execution. 

.EXAMPLE
  Install-HPImageAssistant

.EXAMPLE
  Install-HPImageAssistant -Quiet

.EXAMPLE
  Install-HPImageAssistant -Extract -DestinationPath "c:\staging\hpia"

.LINK
  [Get-Softpaq](https://developers.hp.com/hp-client-management/doc/Get-Softpaq)

.LINK
  [Get-SoftpaqMetadataFile](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqMetadataFile)

.LINK
  [Get-SoftpaqList](https://developers.hp.com/hp-client-management/doc/Get-SoftpaqList)

.LINK
  [Clear-SoftpaqCache](https://developers.hp.com/hp-client-management/doc/Clear-SoftpaqCache)
#>
function Install-HPImageAssistant {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Install-HPImageAssistant")]
  param(
    [Parameter(Position = 0,Mandatory = $false,ParameterSetName = "ExtractParams")]
    [switch]$Extract,

    [Parameter(Position = 1,Mandatory = $false,ParameterSetName = "ExtractParams")]
    [ValidatePattern('^[a-zA-Z]:\\')]
    [string]$DestinationPath,

    [Parameter(Position = 2,Mandatory = $false)]
    [System.IO.DirectoryInfo]$CacheDir,

    [Parameter(Position = 3,Mandatory = $false)]
    [int]$MaxRetries = 0,

    [Parameter(Position = 4,Mandatory = $false)]
    [string]$Source = "https://hpia.hpcloud.hp.com/HPIAMsg.cab",

    [Parameter(Position = 5,Mandatory = $false)]
    [switch]$Quiet
  )

  if ($quiet.IsPresent) { $progress = -not $quiet }
  else { $progress = $true }

  $cacheDir = Get-HPPrivateCacheDirPath ($cacheDir)

  $fallbackSource = "https://ftp.hp.com/pub/caps-softpaq/cmit/imagepal/HPIAMsg.cab"

  $sourceFile = Get-HPPrivateTemporaryFileName -FileName "HPIAMsg.cab" -cacheDir $cacheDir
  $downloadedFile = "$sourceFile.dir\HPIAMsg.xml"

  $try_on_ftp = $false
  try {
    $result = Test-HPPrivateIsDownloadNeeded -url $source -File $sourceFile -Verbose:$VerbosePreference
    if ($result[1] -eq $true) {
      Write-Verbose "Trying to download $source from AWS Server..."
    }
  }
  catch {
    $try_on_ftp = $true
  }

  if ($try_on_ftp) {
    try {
      Write-Verbose "$source not found on AWS Server. Trying to download it from FTP Server..."
      $source = $fallbackSource
      $result = Test-HPPrivateIsDownloadNeeded -url $source -File $sourceFile -Verbose:$VerbosePreference
      if ($result[1] -eq $true) {
        Write-Verbose "Trying to download $source from FTP Server..."
      }
    }
    catch {
      if ($result[1] -eq $false) {
        Write-Host -ForegroundColor Magenta "data file not found"
      }
    }
  }

  if ($result[1] -eq $true) {
    Write-Verbose "Cleaning cached data and downloading the data file."
    Invoke-HPPrivateDeleteCachedItem -cab $sourceFile
    Invoke-HPPrivateDownloadFile -url $source -Target $sourceFile -progress $progress -Verbose:$VerbosePreference -maxRetries $maxRetries
  }

  Write-Verbose "Downloaded file is : $downloadedFile"
  # Need to make sure that the expanded data file exists and is not corrupted. 
  # Otherwise, expand the cab file.
  if (-not (Test-Path $downloadedFile) -or (-not (Test-HPPrivateIsValidXmlFile -File $downloadedFile)))
  {
    Write-Verbose "Extracting the data file, looking for $downloadedFile."
    $file = Invoke-HPPrivateExpandCAB -cab $sourceFile -expectedFile $downloadedFile
    Write-Verbose $file
  }

  Write-Verbose "Reading XML document  $downloadedFile"
  # Default encoding for PS5.1 is Default meaning the encoding that correpsonds to the system's active code page
  # Default encoding for PS7.3 is utf8NoBOM 
  [xml]$data = Get-Content $downloadedFile -Encoding UTF8
  Write-Verbose "Parsing the document"

  # Getting the SoftPaq information
  $SoftpaqVersion = $data.ImagePal.HPIALatest.Version
  $SoftpaqUrl = $data.ImagePal.HPIALatest.SoftpaqURL
  $Softpaq = $SoftpaqUrl.Split('/')[-1]
  $SoftpaqExtractedFolderName = $Softpaq.ToLower().trimend(".exe")

  if($DestinationPath){
    # remove trailing backslashes in DestinationPath because SoftPaqs do not allow execution with trailing backslashes
    $DestinationPath = $DestinationPath.TrimEnd('\')

    # use DestinationPath if given for downloads 
    $TargetFile = Join-Path -Path $DestinationPath -ChildPath $Softpaq
  }
  else {
    $TargetFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Softpaq)
  }
  Write-Verbose "SoftPaq Version: $SoftpaqVersion"
  Write-Verbose "SoftPaq URL: $SoftpaqUrl"

  $params = @{
    url = $SoftpaqUrl
    Target = $TargetFile
    MaxRetries = $MaxRetries
    progress = $progress
  }

  try {
    Invoke-HPPrivateDownloadFile @params
    Write-Verbose "Successfully downloaded SoftPaq at $TargetFile"
    # if Extract and Destination location is specified, proceed to extract the SoftPaq
    if ($Extract) {
      if (!$DestinationPath) {
        $DestinationPath = Join-Path -Path $(Get-Location) -ChildPath $SoftpaqExtractedFolderName
      }
      if ($DestinationPath -match [regex]::Escape([System.Environment]::SystemDirectory)) {
        throw 'Windows System32 is not a valid destination path.'
      }
      
      $tempWorkingPath = $(Get-HPPrivateTempPath)
      $workingPath = Join-Path -Path $tempWorkingPath -ChildPath $Softpaq
      Write-Verbose "Copying downloaded SoftPaq to temporary working directory $workingPath"
      
      if(-not (Test-Path -Path $tempWorkingPath)){
        Write-Verbose "Part of the temporary working directory does not exist. Creating $tempWorkingPath before copying" 
        New-Item -Path $tempWorkingPath -ItemType "Directory" -Force | Out-Null 
      }
  
      Copy-Item -Path $TargetFile -Destination $workingPath -Force

      Invoke-PostDownloadSoftpaqAction -downloadedFile $workingPath -Action "Extract" -Destination $DestinationPath
      Write-Verbose "SoftPaq self-extraction finished at $DestinationPath"
      Write-Verbose "Remove SoftPaq from the temporary working directory $workingPath"
      Remove-Item -Path $workingPath -Force
    }
    Write-Verbose "Success"
  }
  catch {
    if (-not $Quiet) {
      Write-Host -ForegroundColor Magenta $_.Exception.Message
    }
    throw $_.Exception
  }
}



# private functionality below

function matchCategory ([string]$cat,[string[]]$allowed)
{
  if ($allowed -eq $null) { return $true }
  if ($cat.StartsWith("Driver") -eq $true) { return $allowed -eq "driver" }
  if ($cat.StartsWith("Operating System -") -eq $true) { return $allowed -eq "os" }
  if ($cat.StartsWith("Manageability - Driver Pack") -eq $true) { return $allowed -eq "driverpack" }
  if ($cat.StartsWith("Manageability - UWP Pack") -eq $true) { return $allowed -eq "UWPPack" }
  if ($cat.StartsWith("Manageability -") -eq $true) { return $allowed -eq "manageability" }
  if ($cat.StartsWith("Utility -") -eq $true) { return $allowed -eq "utility" }
  if (($cat.StartsWith("Dock -") -eq $true) -or ($cat -eq "Docks")) { return $allowed -eq "dock" }
  if (($cat -eq "BIOS") -or ($cat.StartsWith("BIOS -") -eq $true)) { return $allowed -eq "BIOS" }
  if ($cat -eq "firmware") { return $allowed -eq "firmware" }
  if ($cat -eq "diagnostic") { return $allowed -eq "diagnostic" }
  else {
    return $allowed -eq "software"
  }
  return $false
}

function matchAllCharacteristic ([string[]]$targetedCharacteristic,[string]$SSM,[string]$DPB,[string]$UWP)
{
  if ($targetedCharacteristic -eq $null) { return $true }
  if ($targetedCharacteristic.Count -eq 0) { return $true }

  $ContainsAllCharacteristic = $true

  foreach ($characteristic in $targetedCharacteristic)
  {
    switch ($characteristic.trim().ToLower()) {
      "ssm"
      {
        if ($SSM.trim().ToLower() -eq "false") { $ContainsAllCharacteristic = $false }
      }
      "dpb"
      {
        if ($DPB.trim().ToLower() -eq "false") { $ContainsAllCharacteristic = $false }
      }
      "uwp"
      {
        if ($UWP.trim().ToLower() -ne "uwp") { $ContainsAllCharacteristic = $false }
      }
    }
  }
  return $ContainsAllCharacteristic
}



function Release-Ref ($ref) {
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$ref) | Out-Null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
}

# create a friendly name from SoftPaq metadata (CVA)
function getfriendlyFileName
{
  [CmdletBinding()]
  param(
    [int]$number,
    $info,
    [string]$from
  )

  try {
    $title = "sp$number"

    #if title was passed in, we use it
    if ($from) { $title = $from }

    #else if object was passed in, we use it
    elseif ($info -ne $null) { $title = ($info | Out-SoftpaqField Title) }

    #else use a default
    else { $title = "(No description available)" }

    $pass1 = removeInvalidCharacters $title
    $pass2 = $pass1.trim()
    $pass3 = $pass2 -replace ('\s+','_')
    return $number.ToString("sp######") + "-" + $pass3
  }
  catch {
    Write-Host -ForegroundColor Magenta "Could not determine friendly name so using SoftPaq number."
    Write-Host -ForegroundColor Magenta $_.Exception.Message
    return "sp$number"
  }
}

# remove invalid characters from a filename
function removeInvalidCharacters ([string]$Name) {
  $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
  $re = "[{0}]" -f [regex]::Escape($invalidChars)
  return ($Name -replace $re)
}

#shortcuts to various sections of CVA file
$mapper = @{
  "Install" = "Install Execution|Install";
  "SilentInstall" = "Install Execution|SilentInstall";
  "Number" = "Softpaq|SoftpaqNumber";
  "Title" = "Software Title|%lang";
  "Description" = "%lang.Software Description|_body";
  "Platforms" = "System Information|%KeyValues(^SysName.*$)";
  "PlatformIDs" = "System Information|%KeyValues(^SysId.*$)";
  "SoftPaqSHA256" = "Softpaq|SoftPaqSHA256";
  "Version" = "General|VendorVersion";
};

#ISO to CVA language mapper
$lang_mapper = @{
  "en" = "us";
};


# navigate a CVA structure
function descendNodesAndGet ($root,$field,$lang = "en")
{
  $f1 = $mapper[$field].Replace("%lang",$lang_mapper[$lang])
  $f = $f1.Split("|")
  $node = $root

  foreach ($c in $f) {
    if ($c -match "^%KeyValues\(.*\)$") { return $node }
    if ($c -match "^%Keys\(.*\)$") { return $node }
    $node = $node[$c]
  }
  $node
}

function New-HPPrivateSoftPaqListManifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [PSCustomObject[]]$Softpaqs,

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    $Name,

    [ValidateSet('win10', 'win11')]
    [string]$Os,

    [Parameter(Mandatory = $false)]
    [string]$OSVer,

    [Parameter(Mandatory = $false)]
    [ValidateSet('JSON','XML')]
    $Format = 'JSON'
  )

  $manifest = [PSCustomObject]@{
    Date = $(Get-Date -Format s)
    Name = $Name
    Os = $Os
    OsVer = $OSVer
    SoftPaqs = @($Softpaqs)
  }

  switch ($Format) {
    'XML' { $result = ConvertTo-Xml -InputObject $manifest -As String -Depth 2 -NoTypeInformation }
    'JSON' { $result = ConvertTo-Json -InputObject $manifest }
  }

  return $result
}

<#
.SYNOPSIS
  Creates a Driver Pack for a specified list of SoftPaqs

.DESCRIPTION
  This command creates a Driver Pack for a specified list of SoftPaqs in the following formats:

  - NoCompressedFile - All drivers saved in a regular folder
  - ZIP - All drivers compressed in a ZIP file
  - WIM - All drivers packed in a Windows Imaging Format

  Please note that this command is called in the New-HPDriverPack command if no errors occurred. 


.PARAMETER Softpaqs
  Specifies a list of SoftPaqs to be included in the Driver Pack. Additionally, this parameter can be specified by piping the output of the Get-SoftpaqList command to this command.

.PARAMETER Os
  Specifies an OS for this command to filter based on. The value must be 'win10' or 'win11'. If not specified, the current platform OS is used.

.PARAMETER OsVer
  Specifies an OS version for this command to filter based on. The value must be a string value specifying the target OS Version (e.g. '1809', '1903', '1909', '2004', '2009', '21H1', '21H2', '22H2', '23H2', '24H2', etc). If this parameter is not specified, the current operating system version is used.

.PARAMETER Format
   Specifies the output format of the Driver Pack. The value must be one of the following values:
  - NoCompressedFile
  - ZIP
  - WIM

.PARAMETER Path
  Specifies an absolute path for the Driver Pack directory. The current directory is used by default if this parameter is not specified.

.PARAMETER Name
  Specifies a custom name for the Driver Pack e.g. DP880D

.PARAMETER Overwrite
  If specified, this command will force overwrite any existing file with the same name during driver pack creation.

.PARAMETER TempDownloadPath
  Specifies an alternate temporary location to download content. Please note that this location and all files inside will be deleted once driver pack is created. If not specified, the default temporary directory path is used.

.EXAMPLE
  Get-SoftpaqList -platform 880D -os 'win10' -osver '21H2' | New-HPBuildDriverPack -Os Win10 -OsVer 21H1 -Name 'DP880D'

.EXAMPLE
  Get-SoftpaqList -platform 880D -os 'win10' -osver '21H2' | New-HPBuildDriverPack -Format Zip -Os Win10 -OsVer 21H1 -Name 'DP880D'

.EXAMPLE
  Get-SoftpaqList -platform 880D -os 'win10' -osver '21H2' | ?{$_.DPB -Like 'true' -and $_.id -notin @('sp137116') -and $_.name -notmatch 'AMD|USB'} | New-HPBuildDriverPack -Path 'C:\MyDriverPack' -Format Zip -Os Win10 -OsVer 21H1 -Name 'DP880D'

.NOTES
  - Admin privilege is required.
  - Running this command in PowerShell ISE is not supported and may produce inconsistent results.
#>
function New-HPBuildDriverPack {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPBuildDriverPack")]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)]
    [array]$Softpaqs,

    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateSet('win10', 'win11')]
    [string]$Os,

    [ValidateSet("1809","1903","1909","2004","2009","21H1","21H2","22H2", "23H2", "24H2")] # keep in sync with the Repo module
    [Parameter(Mandatory = $false, Position = 3)]
    [string]$OSVer,

    [Parameter(Mandatory = $false, Position = 4)]
    [System.IO.DirectoryInfo]$Path,

    [Parameter(Mandatory = $false, Position = 5)]
    [ValidateSet('wim','zip','NoCompressedFile')]
    $Format = 'NoCompressedFile',

    [Parameter(Mandatory = $true, Position = 6)]
    [ValidatePattern("^\w{1,20}$")]
    [string]$Name,

    [Parameter(Mandatory = $false, Position = 7)]
    [switch]$Overwrite,

    [Parameter(Mandatory = $false, Position = 8)] 
    [System.IO.DirectoryInfo]$TempDownloadPath
  )
  BEGIN {
    $softpaqsArray = @()
  }
  PROCESS {
    $softpaqsArray += $Softpaqs
  }
  END {
    if (!$Os) {
      $Os = Get-HPPrivateCurrentOs
      Write-Warning "OS has not been specified, using OS from the current system: $Os"
    }
  
    if (!$OsVer) {
      $revision = (GetCurrentOSVer).ToUpper()
      if ($revision -notin "1809","1903","1909","2004","2009","21H1","21H2","22H2", "23H2", "24H2") {
        throw "OSVer $revision currently not supported"
      }
      $OsVer = $revision
      Write-Warning "OSVer has not been specified, using the OSVer from the current system: $OsVer"
    }

    # ZIP and WIM format requires admin privilege
    if (-not (Test-IsElevatedAdmin)) {
      throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
    }

    [System.IO.DirectoryInfo]$cwd = (Get-Location).Path
    if (-not $Path) {
      $Path = $cwd
    }

    if ($TempDownloadPath) {
      $downloadPath = $TempDownloadPath
    }
    else {
      $downloadPath = Get-HPPrivateTempFilePath
    }

    $finalPath = Join-Path -Path $Path.FullName -ChildPath $Name

    if ($Format -eq 'NoCompressedFile') {
      if ([System.IO.Directory]::Exists($finalPath)) {
        if ($Overwrite.IsPresent) {
          Write-Verbose "$finalPath already exists, overwriting the directory"
          Remove-Item -LiteralPath $finalPath -Force -Recurse
        }
        else {
          # find new name that doesn't exist
          $existingFileIncrement = 0
          Get-ChildItem -Path "$($finalPath)_*" -Directory | Where-Object {
            if ($_.BaseName -Match '_([0-9]+)$') {
              [int]$i = [int]($Matches[1])
              if ($i -gt $existingFileIncrement) {
                $existingFileIncrement = $i
              }
            }
          }
          $existingFileIncrement += 1
          $finalPath = "$($finalPath)_$($existingFileIncrement)"
        }
      }
      $workingPath = $finalPath
    }
    else {
      $workingPath = Get-HPPrivateTempFilePath
    }

    Write-Verbose "Working directory: $workingPath"

    if ($PSVersionTable.PSEdition -eq 'Desktop' -and -not $(Test-HPPrivateIsLongPathSupported)) {
      Write-Verbose "Unicode paths are required"
      if (Test-HPPrivateIsRunningOnISE) {
        Write-Warning 'Running this command in PowerShell ISE is not supported and may produce inconsistent results.'
      }
      $finalPath = Get-HPPrivateUnicodePath -Path $finalPath
      $workingPath = Get-HPPrivateUnicodePath -Path $workingPath
      $downloadPath = Get-HPPrivateUnicodePath -Path $downloadPath
    }

    if ($Format -eq 'NoCompressedFile' -and [System.IO.Directory]::Exists($finalPath)) {
      Write-Verbose "$finalPath already exists, deleting the directory"
      Remove-Item -Path "$finalPath\*" -Recurse -Force -ErrorAction Ignore
      Remove-Item -Path $finalPath -Recurse -Force -ErrorAction Ignore
    }

    if (-not [System.IO.Directory]::Exists($Path)) {
      throw "The absolute path specified to a directory does not exist: $Path"
    }

    Write-Verbose "Creating directory: $workingPath"
    [System.IO.Directory]::CreateDirectory($workingPath) | Out-Null
    if (-not [System.IO.Directory]::Exists($workingPath)) {
      throw "An error occurred while creating directory $workingPath"
    }

    Write-Verbose "Creating downloadPath: $downloadPath"
    [System.IO.Directory]::CreateDirectory($downloadPath) | Out-Null
    if (-not [System.IO.Directory]::Exists($downloadPath)) {
      throw "An error occurred while creating directory $downloadPath"
    }

    $manifestPath = [IO.Path]::Combine($workingPath, 'manifest')
    Write-Verbose "Creating manifest file: $manifestPath.json"
    New-HPPrivateSoftPaqListManifest -Softpaqs $softpaqsArray -Name $Name -Os $Os -OsVer $OsVer -Format Json | Out-File -LiteralPath "$manifestPath.json"
    Write-Verbose "Creating manifest file: $manifestPath.xml"
    New-HPPrivateSoftPaqListManifest -Softpaqs $softpaqsArray -Name $Name -Os $Os -OsVer $OsVer -Format XML | Out-File -LiteralPath "$manifestPath.xml"

    foreach ($ientry in $softpaqsArray) {
      Write-Verbose "Processing $($ientry.id)"
      $url = $ientry.url -Replace "/$($ientry.id).exe$",''
      if (-not ($url -like 'https://*')) {
        $url = "https://$url"
      }
      try {
        $metadata = Get-SoftpaqMetadata -Number $ientry.id -MaxRetries 3 -Url $url
      }
      catch {
        Write-Verbose $_.Exception.Message
        Write-Warning "$($ientry.id) metadata was not found or the SoftPaq is obsolete. This will not be included in the package."
        continue
      }

      if ($metadata.ContainsKey('Devices_INFPath')) {
        # fix folder naming issue when softpaq name contains '/',(ex. "Intel TXT/ACM" driver)
        $downloadFilePath = [IO.Path]::Combine($downloadPath, "$($ientry.id).exe")
        Write-Verbose "Downloading SoftPaq $downloadFilePath"
        try {
          Get-Softpaq -Number $ientry.id -SaveAs $downloadFilePath -MaxRetries 3 -Url $url
        }
        catch {
          Write-Verbose $_.Exception.Message
          Write-Warning "$($ientry.id) was not found or the SoftPaq is obsolete. This will not be included in the package."
          continue
        }
        Write-Verbose "Setting current dir to $($downloadPath)"
        Set-Location -LiteralPath $downloadPath
        $extractFolderName = $ientry.id
        Write-Verbose "Extracting SoftPaq $downloadFilePath to .\$extractFolderName"
        try {
          Start-Process -Wait $downloadFilePath -ArgumentList "-e -f `".\$extractFolderName`"","-s"
        }
        catch {
          Set-Location $cwd
          throw
        }
        Set-Location $cwd

        $OsId = if ($Os -eq 'Win11') { 'W11' } else { 'WT64' }
        $fullInfPathName = "$($OsId)_$($OSVer.ToUpper())_INFPath"
        if ($metadata.Devices_INFPath.ContainsKey($fullInfPathName)) {
          $infPathName = $fullInfPathName
        }
        else {
          # fallback to generic inf path name
          $infPathName = "$($OsId)_INFPath"
        }
        if ($metadata.Devices_INFPath.ContainsKey($infPathName)) {
          Write-Verbose "$infPathName selected"
          $infPaths = $($metadata.Devices_INFPath[$infPathName])
          $finalExtractFolderName = $ientry.id
          $destinationPath = [IO.Path]::Combine($workingPath, $finalExtractFolderName)
          $extractPath = [IO.Path]::Combine($downloadPath, $extractFolderName)
          [System.IO.Directory]::CreateDirectory($destinationPath) | Out-Null
          foreach ($infPath in $infPaths) {
            $infPath = $infPath.TrimStart('.\')
            $absoluteInfPath = [IO.Path]::Combine($extractPath, $infPath)
            Write-Verbose "Copying $absoluteInfPath to $destinationPath"
            Copy-Item $absoluteInfPath $destinationPath -Force -Recurse
          }
        }
        else {
          Write-Warning "INF path $fullInfPathName missing on $($ientry.id) metadata. This will not be included in the package."
        }
      }
      else {
        Write-Warning "$($ientry.id) is not Driver Pack Builder (DPB) compliant. This will not be included in the package."
      }
    }
    Write-Verbose "Removing temporary files $($downloadPath)"
    Remove-Item -Path "$downloadPath\*" -Recurse -Force -ErrorAction Ignore
    Remove-Item -Path $downloadPath -Recurse -Force -ErrorAction Ignore

    switch ($Format) {
      'zip' {
        Write-Verbose "Compressing driver pack to $($Format): $workingPath.zip"
        [System.IO.Compression.ZipFile]::CreateFromDirectory($workingPath, "$workingPath.zip")
        Remove-Item -Path "$workingPath\*" -Recurse -Force -ErrorAction Ignore
        Remove-Item -Path $workingPath -Recurse -Force -ErrorAction Ignore
        if ([System.IO.File]::Exists("$finalPath.$Format")) {
          if ($Overwrite.IsPresent) {
            Write-Verbose "$finalPath.zip already exists, overwriting the file"
            Remove-Item -LiteralPath "$($finalPath).$Format" -Force
          }
          else {
            # find new name that doesn't exist
            $existingFileIncrement = 0
            Get-ChildItem -Path "$($finalPath)_*.$Format" -File | Where-Object {
              if ($_.BaseName -Match '_([0-9]+)$') {
                [int]$i = [int]($Matches[1])
                if ($i -gt $existingFileIncrement) {
                  $existingFileIncrement = $i
                }
              }
            }
            $existingFileIncrement += 1
            $finalPath = "$($finalPath)_$($existingFileIncrement)"
          }
        }
        [System.IO.File]::Move("$workingPath.$Format", "$finalPath.$Format")
        $resultFile = [System.IO.FileInfo]"$finalPath.$Format"
      }
      'wim' {
        Write-Verbose "Compressing driver pack to $($Format): $workingPath.$Format"
        if ([System.IO.File]::Exists("$workingPath.$Format")) {
          # New-WindowsImage will not override existing file
          Remove-Item -LiteralPath "$($workingPath).$Format" -Force
        }
        New-WindowsImage -CapturePath $workingPath -ImagePath "$workingPath.$Format" -CompressionType Max `
          -LogPath $([IO.Path]::Combine($(Get-HPPrivateTempPath), 'DISM.log')) -Name $Name | Out-Null
        Remove-Item -Path "$workingPath\*" -Recurse -Force -ErrorAction Ignore
        Remove-Item -Path $workingPath -Recurse -Force -ErrorAction Ignore

        if ([System.IO.File]::Exists("$finalPath.$Format")) {
          if ($Overwrite.IsPresent) {
            Write-Verbose "$finalPath.wim already exists, overwriting the file"
            Remove-Item -LiteralPath "$($finalPath).$Format" -Force
          }
          else {
            # find new name that doesn't exist
            $existingFileIncrement = 0
            Get-ChildItem -Path "$finalPath*.$Format" | Where-Object {
              if ($_.BaseName -Match '_([0-9]+)$') {
                [int]$i = [int]($Matches[1])
                if ($i -gt $existingFileIncrement) {
                  $existingFileIncrement = $i
                }
              }
            }
            $existingFileIncrement += 1
            $finalPath = "$($finalPath)_$($existingFileIncrement)"
          }
        }
        [System.IO.File]::Move("$workingPath.$Format", "$finalPath.$Format")
        $resultFile = [System.IO.FileInfo]"$finalPath.$Format"
      }
      default {
        $resultFile = [System.IO.DirectoryInfo]$finalPath
      }
    }
    $resultFile
    Write-Host "`nDriver Pack created at $($resultFile.FullName)"
  }
}

function Remove-HPPrivateSoftpaqEntries {
  [CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] $pFullSoftpaqList,
      [Parameter(Mandatory = $true)] [array]$pUnselectList,
      [Parameter(Mandatory = $true)] [boolean]$pUnselectListAsArg
)

  $l_DPBList = @() # list of drivers that will be selected from the full list
  $l_Unselected = @() # list of drivers that were unselected (to display)
  for ($i=0;$i -lt $pFullSoftpaqList.Count; $i++ ) {
      $iUnselectMatched = $null
      # see if the entries contain Softpaqs by name or ID, and remove from list
      foreach ( $iList in $pUnselectList ) { 
          if ( ($pFullSoftpaqList[$i].name -match $iList) -or ($pFullSoftpaqList[$i].id -like $iList) ) { 
              $iUnselectMatched = $true ; $l_Unselected += $pFullSoftpaqList[$i]
              break
          } 
      }
      if ( -not $iUnselectMatched ) { $l_DPBList += $pFullSoftpaqList[$i] }
  }

  if ($l_Unselected.Count -gt 0) {
    Write-Host "Unselected drivers: "
    foreach ( $iun in $l_Unselected ) {
      Write-Host "`t$($iun.id) $($iun.Name) [$($iun.Category)] $($iun.Version) $($iun.ReleaseDate)"
    }
  }

  , $l_DPBList
}

function Remove-HPPrivateOlderSoftpaqEntries {
  [CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] $pFullSoftpaqList
  )
  Write-Host "Removing superseded entries (-RemoveOlder switch option)"
  #############################################################################
  # 1. get a list of Softpaqs with multiple entries
  $l_TmpList = @()
  foreach ( $iEntry in $pFullSoftpaqList ) {
      foreach ( $i in $pFullSoftpaqList ) {    # search for entries that are same names as $iEntry
          if ( ($i.name -match $iEntry.name) -and (-not ($i.id -match $iEntry.id)) -and ($iEntry -notin $l_TmpList)) {
              $l_TmpList += $iEntry         # found an softpaq name with multiple versions
          }
      } # foreach ( $i in $pFullSoftpaqList )
  } # foreach ( $iEntry in $pFullSoftpaqList )
  if ($l_TmpList.Count -gt 0) {
    Write-Host "These drivers have multiple SoftPaqs (have superseded entries)"
    foreach ( $iun in $l_TmpList ) {
      Write-Host "`t$($iun.id) $($iun.Name) [$($iun.Category)] $($iun.Version)"
    }
  }

  #############################################################################
  # 2. from the $lTmpList list, find the latest (highest sp number softpaq) of each
  $l_FinalTmpList = @()
  
  foreach ( $iEntry in $l_TmpList ) {
    # get all the entries with the same name 
    $tmpValue = @()
    $tmpValue += $iEntry
    foreach ( $i in $l_TmpList ) {
      if($iEntry.name -eq $i.name){
        $tmpValue += $i
      }     
    }
      
    # add highest number to list
    $tmpSp = $iEntry.id.substring(2)
    $tmpEntry = $iEntry

    foreach($entry in $tmpValue){
      if($entry.id.substring(2) -gt $tmpSp){
        $tmpEntry = $entry
      }
    }

    # don't add duplicates 
    if($tmpEntry -notin $l_FinalTmpList){
      $l_FinalTmpList += $tmpEntry
    }
  } 

  if ($l_FinalTmpList.Count -gt 0) {
    Write-Host "These SoftPaqs are good - higher SP numbers"
    foreach ( $iun in $l_FinalTmpList ) {
      Write-Host "`t$($iun.id) $($iun.Name) [$($iun.Category)] $($iun.Version)"
    }
  }
  #############################################################################
  # 3. lastly, remove superseeded drivers from main driver pack list
  $l_FinalDPBList = @()
  foreach ( $iEntry in $pFullSoftpaqList ) {
    if ( $l_TmpList.Count -eq 0 -or ($iEntry.name -notin $l_TmpList.name) -or ($iEntry.id -in $l_FinalTmpList.id) ) {
      if ($l_FinalDPBList.Count -eq 0 -or $iEntry.name -notin $l_FinalDPBList.name) { $l_FinalDPBList += $iEntry }
    }
  } # foreach ( $iEntry in $lDPBList )

  , $l_FinalDPBList           # return list of Softpaqs without the superseded Softpaqs
}

<#
.SYNOPSIS
  Creates a Driver Pack for a specified platform ID 

.DESCRIPTION
  This command retrieves SoftPaqs for a specified platform ID to build a Driver Pack in the following formats:

  - NoCompressedFile - All drivers saved in a regular folder 
  - ZIP - All drivers compressed in a ZIP file
  - WIM - All drivers packed in a Windows Imaging Format

  Please note that this command executes the New-HPBuildDriverPack command if no errors occurred. 

.PARAMETER Platform
  Specifies a platform ID to retrieve a list of associated SoftPaqs. If not available, the current platform ID is used.

.PARAMETER Os
  Specifies an OS for this command to filter based on. The value must be 'win10' or 'win11'. If not specified, the current platform OS is used.

.PARAMETER OsVer
  Specifies an OS version for this command to filter based on. The value must be a string value specifying the target OS Version (e.g. '1809', '1903', '1909', '2004', '2009', '21H1', '21H2', '22H2', '23H2', '24H2', etc). If this parameter is not specified, the current operating system version is used.

.PARAMETER Format
   Specifies the output format of the Driver Pack. The value must be one of the following values:
  - NoCompressedFile
  - ZIP
  - WIM

.PARAMETER WhatIf
  If specified, the Driver Pack is not created, and instead, the list of SoftPaqs that would be included in the Driver Pack is displayed.

.PARAMETER RemoveOlder
  If specified, older versions of the same SoftPaq are not included in the Driver Pack.

.PARAMETER UnselectList
  Specifies a list of SoftPaq numbers and SoftPaq names to not be included in the Driver Pack. A partial name can be specified. Examples include 'Docks', 'USB', 'sp123456'.

.PARAMETER Path
  Specifies an absolute path for the Driver Pack directory. The current directory is used by default if this parameter is not specified.

.PARAMETER Url
  Specifies an alternate location for the HP Image Assistant (HPIA) Reference files. This URL must be HTTPS. The Reference files are expected to be at the location pointed to by this URL inside a directory named after the platform ID you want a SoftPaq list for.
  For example, if you want to point to 83b2 Win10 OSVer 2009 reference files, the New-HPDriverPack command will try to find them in this directory structure: $ReferenceUrl/83b2/83b2_64_10.0.2009.cab.
  If not specified, 'https://hpia.hpcloud.hp.com/ref/' is used by default, and fallback is set to 'https://ftp.hp.com/pub/caps-softpaq/cmit/imagepal/ref/'.

.PARAMETER Overwrite
  If specified, this command will force overwrite any existing file with the same name during driver pack creation.

.PARAMETER TempDownloadPath
  Specifies an alternate temporary location to download content. Please note that this location and all files inside will be deleted once driver pack is created. If not specified, the default temporary directory path is used.

  .EXAMPLE
  New-HPDriverPack -WhatIf

.EXAMPLE
  New-HPDriverPack -Platform 880D -OS 'win10' -OSVer '21H2' -Path 'C:\MyDriverPack' -Unselectlist 'sp96688','AMD','USB' -RemoveOlder -WhatIf

.EXAMPLE
  New-HPDriverPack -Platform 880D -OS 'win10' -OSVer '21H2' -Path 'C:\MyDriverPack' -Unselectlist 'sp96688','AMD','USB' -RemoveOlder -Format Zip

.NOTES
  - Admin privilege is required.
  - Running this command in PowerShell ISE is not supported and may produce inconsistent results.
#>
function New-HPDriverPack {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPDriverPack",SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory = $false, Position = 1)]
    [ValidatePattern("^[a-fA-F0-9]{4}$")]
    [string]$Platform,

    [Parameter(Mandatory = $false, Position = 2 )]
    [ValidateSet('win10', 'win11')]
    [string]$Os,

    [ValidateSet("1809","1903","1909","2004","2009","21H1","21H2","22H2", "23H2", "24H2")] # keep in sync with the Repo module
    [Parameter(Mandatory = $false, Position = 3 )]
    [string]$OSVer,

    [Parameter(Mandatory = $false, Position = 4 )]
    [System.IO.DirectoryInfo]$Path,

    [Parameter(Mandatory = $false, Position = 5 )]
    [array]$UnselectList,

    [Parameter(Mandatory = $false, Position = 6 )]
    [switch]$RemoveOlder = $false,

    [Parameter( Mandatory = $false, Position = 7 )]
    [ValidateSet('NoCompressedFile','zip','wim')]
    [string]$Format='NoCompressedFile',

    [Parameter(Mandatory = $false, Position = 8)]
    [string]$Url,

    [Parameter(Mandatory = $false, Position = 9)]
    [switch]$Overwrite,

    [Parameter(Mandatory = $false, Position = 10)]
    [System.IO.DirectoryInfo]$TempDownloadPath
  )

  # 7zip and Win format require admin privilege
  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

    # only allow https or file paths with or without file:// URL prefix
  if ($Url -and -not ($Url.StartsWith("https://",$true,$null) -or [System.IO.Directory]::Exists($Url) -or $Url.StartsWith("file://",$true,$null))) {
    throw [System.ArgumentException]"Only HTTPS or valid existing directory paths are supported."
  }

  if (!$Platform) {
    $Platform = Get-HPDeviceProductID
  }

  if (!$Os) {
    $Os = Get-HPPrivateCurrentOs
  }

  if (!$OsVer) {
    $revision = (GetCurrentOSVer).ToUpper()
    if ($revision -notin "1809","1903","1909","2004","2009","21H1","21H2","22H2", "23H2", "24H2") {
      throw "OSVer $revision currently not supported"
    }
    $OsVer = $revision
  }

  $bitness = 64

  Write-Host "Creating Driver Pack for Platform $Platform, $Os-$OsVer $($bitness)b"

  $params = @{
    Platform = $Platform
    Os = $Os
    OsVer = $OsVer
    Bitness = $bitness
    MaxRetries = 3
  }
  if ($Url) {
    $params.Url = $Url
  }

  try {
    [array]$lFullDPBList = Get-SoftpaqList @params -Verbose:$VerbosePreference -AddHttps | Where-Object { ($_.DPB -like 'true') }
  }
  catch {
    Write-Host "SoftPaq list not available for the platform or OS specified"
    throw $_.Exception.Message
  }

  # remove any Softpaqs matching names in $UnselectList from the returned list
  if ($UnselectList -and $UnselectList.Count -gt 0) {
      $UnselectListAsArgument = $PSBoundParameters.ContainsKey("UnselectList")
      [array]$DPBList = Remove-HPPrivateSoftpaqEntries -pFullSoftpaqList $lFullDPBList -pUnselectList $UnselectList -pUnselectListAsArg $UnselectListAsArgument
  }
  else {
    [array]$DPBList = $lFullDPBList
  }

  # remove any Softpaqs matching names in $UnselectList from the returned list
  if ($RemoveOlder) {
      $FinalListofSoftpaqs = Remove-HPPrivateOlderSoftpaqEntries -pFullSoftpaqList $DPBList
      [array]$DPBList = $FinalListofSoftpaqs
  }

  if ($DPBList.Count -eq 0) {
    Write-Host "Final list of SoftPaqs is empty, no Driver Pack created"
  }
  else {
    Write-Host "Final list of SoftPaqs for Driver Pack"
    foreach ($iFinal in $DPBList) {
      Write-Host "`t$($iFinal.id) $($iFinal.Name) [$($iFinal.Category)] $($iFinal.Version) $($iFinal.ReleaseDate)"
    }
  }

  # show which selected drivers contain UWP/appx applications (UWP = true)
  $UWPList = @($DPBList | Where-Object { $_.UWP -like 'true' })
  if ($UWPList -and $UWPList.Count -gt 0) {
    Write-Host 'The following selected Drivers contain UWP/appx Store apps'
    foreach ($iUWP in $UWPList) {
      Write-Host "`t$($iUWP.id) $($iUWP.Name) [$($iUWP.Category)] $($iUWP.Version) $($iUWP.ReleaseDate)"
    }
  }

  # create the driver pack
  if ($pscmdlet.ShouldProcess($Platform)) {
    if ($DPBList.Count -gt 0) {
      $params = @{
        Softpaqs = $DPBList
        Name = "DP$Platform"
        Format = $Format
        Os = $Os
        OsVer = $OSVer
        TempDownloadPath = $TempDownloadPath
      }
      if ($Path) {
        $params.Path = $Path
      }
      return New-HPBuildDriverPack @params -Overwrite:$Overwrite
    }
  }
}

<#
.SYNOPSIS
  Creates a UWP Driver Pack for a specified platform ID

.DESCRIPTION
  This command retrieves SoftPaqs for a specified platform ID to build a UWP Driver Pack in the following formats:

  - NoCompressedFile - All drivers saved in a regular folder 
  - ZIP - All drivers compressed in a ZIP file
  - WIM - All drivers packed in a Windows Imaging Format

.PARAMETER Platform
  Specifies a platform ID to retrieve a list of associated SoftPaqs. If not available, the current platform ID is used.

.PARAMETER Os
  Specifies an OS for this command to filter based on. The value must be 'win10' or 'win11'. If not specified, the current platform OS is used.

.PARAMETER OsVer
  Specifies an OS version for this command to filter based on. The value must be a string value specifying the target OS Version (e.g. '22H2', '23H2', '24H2', etc). If this parameter is not specified, the current operating system version is used.

.PARAMETER Format
  Specifies the output format of the Driver Pack. The value must be one of the following values:
  - NoCompressedFile
  - ZIP
  - WIM

.PARAMETER WhatIf
  If specified, the UWP Driver Pack is not created, and instead, the list of SoftPaqs that would be included in the UWP Driver Pack is displayed.

.PARAMETER UnselectList
  Specifies a list of SoftPaq numbers and SoftPaq names to not be included in the UWP Driver Pack. A partial name can be specified. Examples include 'Docks', 'USB', 'sp123456'.

.PARAMETER Path
  Specifies an absolute path for the UWP Driver Pack directory. The current directory is used by default if this parameter is not specified.

.PARAMETER Url
  Specifies an alternate location for the HP Image Assistant (HPIA) reference files. This URL must be HTTPS. The Reference files are expected to be at the location pointed to by this URL inside a directory named after the platform ID you want a SoftPaq list for. If not specified, https://hpia.hpcloud.hp.com/ref is used by default.

  For example, if you want to point to 8A05 Win11 OSVer 22H2 reference files, New-HPUWPDriverPack will try to find them in this directory structure: $ReferenceUrl/8a05/8a05_64_11.0.22h2.cab

.PARAMETER Overwrite
  If specified, this command will force overwrite any existing file with the same name during UWP Driver Pack creation.

.PARAMETER TempDownloadPath
  Specifies an alternate temporary location to download content. Please note that this location and all files inside will be deleted once driver pack is created. If not specified, the default temporary directory path is used.

.EXAMPLE
  New-HPUWPDriverPack -WhatIf

.EXAMPLE
  New-HPUWPDriverPack -Platform 8A05 -OS 'win11' -OSVer '22H2' -Path 'C:\MyDriverPack' -Unselectlist 'sp140688','Wacom' -WhatIf

.EXAMPLE
  New-HPUWPDriverPack -Platform 8A05 -OS 'win10' -OSVer '22H2' -Path 'C:\MyDriverPack' -Unselectlist 'sp140688','Wacom' -Format ZIP

.NOTES
  - Admin privilege is required.
  - Running this command in PowerShell ISE is not supported and may produce inconsistent results.
  - Currently only platform generations G8 and above are supported, and operating systems 22H2 and above.
#>
function New-HPUWPDriverPack {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPUWPDriverPack",SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory = $false, Position = 1)]
    [ValidatePattern("^[a-fA-F0-9]{4}$")]
    [string]$Platform,

    [Parameter(Mandatory = $false, Position = 2 )]
    [ValidateSet('win10', 'win11')]
    [string]$Os,

    [ValidateSet("22H2", "23H2", "24H2")] # keep in sync with the Repo module, but only 22H2 and above are supported
    [Parameter(Mandatory = $false, Position = 3 )]
    [string]$OSVer,

    [Parameter(Mandatory = $false, Position = 4 )]
    [System.IO.DirectoryInfo]$Path,

    [Parameter(Mandatory = $false, Position = 5 )]
    [array]$UnselectList,

    [Parameter( Mandatory = $false, Position = 6 )]
    [ValidateSet('NoCompressedFile','ZIP','WIM')]
    [string]$Format='NoCompressedFile',

    [Parameter(Mandatory = $false, Position = 7)]
    [string]$Url = "https://hpia.hpcloud.hp.com/ref",

    [Parameter(Mandatory = $false, Position = 8)]
    [switch]$Overwrite,

    [Parameter(Mandatory = $false, Position = 9)]
    [System.IO.DirectoryInfo]$TempDownloadPath
  )

  # 7zip and Win format require admin privilege
  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

    # only allow https or file paths with or without file:// URL prefix
  if ($Url -and -not ($Url.StartsWith("https://",$true,$null) -or [System.IO.Directory]::Exists($Url) -or $Url.StartsWith("file://",$true,$null))) {
    throw [System.ArgumentException]"Only HTTPS or valid existing directory paths are supported."
  }

  if (!$Platform) {
    $Platform = Get-HPDeviceProductID
  }

  if (!$Os) {
    $Os = Get-HPPrivateCurrentOs
  }

  if (!$OsVer) {
    $revision = (GetCurrentOSVer).ToUpper()
    if ($revision -notin "22H2", "23H2", "24H2") {
      throw "OSVer $revision currently not supported"
    }
    $OsVer = $revision
  }

  $bitness = 64
  Write-Host "Checking if platform supports UWP Driver Packs: $Platform, $Os-$OsVer $($bitness)b"

  # Check if device is UWP compliant
  if ((Get-HPDeviceDetails -Platform $Platform -Url $Url).UWPDriverPackSupport -eq $true) {
    Write-Verbose "Platform $Platform is supported"
  }
  else {
    throw "Platform $Platform is currently not supported"
  }

  Write-Host "Creating UWP Driver Pack for Platform $Platform, $Os-$OsVer $($bitness)b"
  $params = @{
    Platform = $Platform
    Os = $Os
    OsVer = $OsVer
    Bitness = $bitness
    MaxRetries = 3
  }

  try {
    [array]$uwpFullList = Get-SoftpaqList @params -Url $Url -Verbose:$VerbosePreference -AddHttps -Category Driver | Where-Object { ($_.DPB -like 'true' -and $_.UWP -like 'true') }
  }
  catch {
    Write-Host "SoftPaq list not available for the platform or OS specified"
    throw $_.Exception.Message
  }

  # Remove any Softpaqs matching names in $UnselectList from the returned list
  if ($UnselectList -and $UnselectList.Count -gt 0) {
      $UnselectListAsArgument = $PSBoundParameters.ContainsKey("UnselectList")
      [array]$UWPList = Remove-HPPrivateSoftpaqEntries -pFullSoftpaqList $uwpFullList -pUnselectList $UnselectList -pUnselectListAsArg $UnselectListAsArgument
  }
  else {
    [array]$UWPList = $uwpFullList
  }

  Write-Host "Final list of SoftPaqs for UWP Driver Pack"
  foreach ($sp in $UWPList) {
    Write-Host "`t$($sp.id) $($sp.Name) [$($sp.Category)] $($sp.Version) $($sp.ReleaseDate)"
  }

  # create the driver pack
  if ($pscmdlet.ShouldProcess($Platform)) {
    if ($UWPList.Count -gt 0) {
      $params = @{
        Softpaqs = $UWPList
        Name = "UWP$Platform"
        Format = $Format
        Os = $Os
        OsVer = $OSVer
        TempDownloadPath = $TempDownloadPath
      }
      if ($Path) {
        $params.Path = $Path
      }
      return New-HPPrivateBuildUWPDriverPack @params -Overwrite:$Overwrite
    }
  }
}

function New-HPPrivateBuildUWPDriverPack {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)]
    [array]$Softpaqs,

    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateSet('win10', 'win11')]
    [string]$Os,

    [ValidateSet("22H2", "23H2", "24H2")] # keep in sync with the Repo module, but only 22H2 and above are supported
    [Parameter(Mandatory = $false, Position = 3)]
    [string]$OSVer,

    [Parameter(Mandatory = $false, Position = 4)]
    [System.IO.DirectoryInfo]$Path,

    [Parameter(Mandatory = $false, Position = 5)]
    [ValidateSet('wim','zip','NoCompressedFile')]
    $Format = 'NoCompressedFile',

    [Parameter(Mandatory = $true, Position = 6)]
    [ValidatePattern("^\w{1,20}$")]
    [string]$Name,

    [Parameter(Mandatory = $false, Position = 7)]
    [switch]$Overwrite,

    [Parameter(Mandatory = $false, Position = 8)]
    [System.IO.DirectoryInfo]$TempDownloadPath
  )
  BEGIN {
    $softpaqsArray = @()
  }
  PROCESS {
    $softpaqsArray += $Softpaqs
  }
  END {
    if (!$Os) {
      $Os = Get-HPPrivateCurrentOs
    }
  
    if (!$OsVer) {
      $revision = (GetCurrentOSVer).ToUpper()
      if ($revision -notin "22H2", "23H2", "24H2") {
        throw "OSVer $revision currently not supported"
      }
      $OsVer = $revision
    }

    # ZIP and WIM format requires admin privilege
    if (-not (Test-IsElevatedAdmin)) {
      throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
    }

    [System.IO.DirectoryInfo]$pwd = (Get-Location).Path
    if (-not $Path) {
      $Path = $pwd
    }

    if ($TempDownloadPath) {
      $downloadPath = $TempDownloadPath
    }
    else {
      $downloadPath = Get-HPPrivateTempFilePath
    }

    $finalPath = Join-Path -Path $Path.FullName -ChildPath $Name

    if ($Format -eq 'NoCompressedFile') {
      if ([System.IO.Directory]::Exists($finalPath)) {
        if ($Overwrite.IsPresent) {
          Write-Verbose "$finalPath already exists, overwriting the directory"
          Remove-Item -LiteralPath $finalPath -Force -Recurse
        }
        else {
          # find new name that doesn't exist
          $existingFileIncrement = 0
          Get-ChildItem -Path "$($finalPath)_*" -Directory | Where-Object {
            if ($_.BaseName -Match '_([0-9]+)$') {
              [int]$i = [int]($Matches[1])
              if ($i -gt $existingFileIncrement) {
                $existingFileIncrement = $i
              }
            }
          }
          $existingFileIncrement += 1
          $finalPath = "$($finalPath)_$($existingFileIncrement)"
        }
      }
      $workingPath = $finalPath
    }
    else {
      $workingPath = Get-HPPrivateTempFilePath
    }

    Write-Verbose "Working directory: $workingPath"

    if ($PSVersionTable.PSEdition -eq 'Desktop' -and -not $(Test-HPPrivateIsLongPathSupported)) {
      Write-Verbose "Unicode paths are required"
      if (Test-HPPrivateIsRunningOnISE) {
        Write-Warning 'Running this command in PowerShell ISE is not supported and may produce inconsistent results.'
      }
      $finalPath = Get-HPPrivateUnicodePath -Path $finalPath
      $workingPath = Get-HPPrivateUnicodePath -Path $workingPath
      $downloadPath = Get-HPPrivateUnicodePath -Path $downloadPath
    }

    if ($Format -eq 'NoCompressedFile' -and [System.IO.Directory]::Exists($finalPath)) {
      Write-Verbose "$finalPath already exists, deleting the directory"
      Remove-Item -Path "$finalPath\*" -Recurse -Force -ErrorAction Ignore
      Remove-Item -Path $finalPath -Recurse -Force -ErrorAction Ignore
    }

    if (-not [System.IO.Directory]::Exists($Path)) {
      throw "The absolute path specified to a directory does not exist: $Path"
    }

    Write-Verbose "Creating directory: $workingPath"
    [System.IO.Directory]::CreateDirectory($workingPath) | Out-Null
    if (-not [System.IO.Directory]::Exists($workingPath)) {
      throw "An error occurred while creating directory $workingPath"
    }

    Write-Verbose "Creating downloadPath: $downloadPath"
    [System.IO.Directory]::CreateDirectory($downloadPath) | Out-Null
    if (-not [System.IO.Directory]::Exists($downloadPath)) {
      throw "An error occurred while creating directory $downloadPath"
    }

    $manifestPath = [IO.Path]::Combine($workingPath, 'manifest')
    Write-Verbose "Creating manifest file: $manifestPath.json"
    New-HPPrivateSoftPaqListManifest -Softpaqs $softpaqsArray -Name $Name -Os $Os -OsVer $OsVer -Format Json | Out-File -LiteralPath "$manifestPath.json"
    Write-Verbose "Creating manifest file: $manifestPath.xml"
    New-HPPrivateSoftPaqListManifest -Softpaqs $softpaqsArray -Name $Name -Os $Os -OsVer $OsVer -Format XML | Out-File -LiteralPath "$manifestPath.xml"

    foreach ($softpaq in $softpaqsArray) {
      Write-Verbose "Processing $($softpaq.id)"
      $url = $softpaq.url -Replace "/$($softpaq.id).exe$",''
      $downloadFilePath = [IO.Path]::Combine($downloadPath, "$($softpaq.id).exe")
      Write-Verbose "Downloading SoftPaq $downloadFilePath"
      try {
        Get-Softpaq -Number $softpaq.id -SaveAs $downloadFilePath -MaxRetries 3 -Url $url
      }
      catch {
        Write-Verbose $_.Exception.Message
        Write-Warning "$($softpaq.id) was not found or the SoftPaq is Obsolete. This will not be included in the package."
        continue
      }
      Write-Verbose "Setting current dir to $($downloadPath)"
      Set-Location -LiteralPath $downloadPath
      $extractFolderName = $softpaq.id
      Write-Verbose "Extracting SoftPaq $downloadFilePath to .\$extractFolderName"
      try {
        Start-Process -Wait $downloadFilePath -ArgumentList "-e -f `".\$extractFolderName`"","-s"
      }
      catch {
        Set-Location $pwd
        throw
      }
      Set-Location $pwd

      $extractPath = [IO.Path]::Combine($downloadPath, $extractFolderName)
      $appPath = [IO.Path]::Combine($extractPath, 'src')
      $installAppPath = [IO.Path]::Combine($appPath, 'InstallApp.cmd')
      $installAppxPath = [IO.Path]::Combine($appPath, 'appxinst.cmd')
      $appPath = [IO.Path]::Combine($appPath, 'App')
      $destinationPath = [IO.Path]::Combine($workingPath, $extractFolderName)
      $destinationAppPath = [IO.Path]::Combine($destinationPath, 'App')

      if (([System.IO.Directory]::Exists($appPath) -and [System.IO.File]::Exists($installAppPath)) -or
          ([System.IO.Directory]::Exists($appPath) -and [System.IO.File]::Exists($installAppxPath))) {
        Copy-Item $appPath $destinationAppPath -Force -Recurse
        if ([System.IO.File]::Exists($installAppPath)) {
          Copy-Item $installAppPath $destinationPath -Force
        }
        if ([System.IO.File]::Exists($installAppxPath)) {
          Copy-Item $installAppxPath $destinationPath -Force
        }
      }
      else {
        Write-Warning "Directory $appPath or installers are missing on SoftPaq $($softpaq.id). This will not be included in the package."
      }
    }
    Write-Verbose "Removing temporary files $($downloadPath)"
    Remove-Item -Path "$downloadPath\*" -Recurse -Force -ErrorAction Ignore
    Remove-Item -Path $downloadPath -Recurse -Force -ErrorAction Ignore

    $assetsPath = [IO.Path]::Combine($PSScriptRoot, 'assets')
    $installPath = [IO.Path]::Combine($assetsPath, 'InstallAllApps.cmd')
    Copy-Item $installPath $workingPath -Force

    switch ($Format) {
      'zip' {
        Write-Verbose "Compressing driver pack to $($Format): $workingPath.zip"
        [System.IO.Compression.ZipFile]::CreateFromDirectory($workingPath, "$workingPath.zip")
        Remove-Item -Path "$workingPath\*" -Recurse -Force -ErrorAction Ignore
        Remove-Item -Path $workingPath -Recurse -Force -ErrorAction Ignore
        if ([System.IO.File]::Exists("$finalPath.$Format")) {
          if ($Overwrite.IsPresent) {
            Write-Verbose "$finalPath.zip already exists, overwriting the file"
            Remove-Item -LiteralPath "$($finalPath).$Format" -Force
          }
          else {
            # find new name that doesn't exist
            $existingFileIncrement = 0
            Get-ChildItem -Path "$($finalPath)_*.$Format" -File | Where-Object {
              if ($_.BaseName -Match '_([0-9]+)$') {
                [int]$i = [int]($Matches[1])
                if ($i -gt $existingFileIncrement) {
                  $existingFileIncrement = $i
                }
              }
            }
            $existingFileIncrement += 1
            $finalPath = "$($finalPath)_$($existingFileIncrement)"
          }
        }
        [System.IO.File]::Move("$workingPath.$Format", "$finalPath.$Format")
        $resultFile = [System.IO.FileInfo]"$finalPath.$Format"
      }
      'wim' {
        Write-Verbose "Compressing driver pack to $($Format): $workingPath.$Format"
        if ([System.IO.File]::Exists("$workingPath.$Format")) {
          # New-WindowsImage will not override existing file
          Remove-Item -LiteralPath "$($workingPath).$Format" -Force
        }
        New-WindowsImage -CapturePath $workingPath -ImagePath "$workingPath.$Format" -CompressionType Max `
          -LogPath $([IO.Path]::Combine($(Get-HPPrivateTempPath), 'DISM.log')) -Name $Name | Out-Null
        Remove-Item -Path "$workingPath\*" -Recurse -Force -ErrorAction Ignore
        Remove-Item -Path $workingPath -Recurse -Force -ErrorAction Ignore

        if ([System.IO.File]::Exists("$finalPath.$Format")) {
          if ($Overwrite.IsPresent) {
            Write-Verbose "$finalPath.wim already exists, overwriting the file"
            Remove-Item -LiteralPath "$($finalPath).$Format" -Force
          }
          else {
            # find new name that doesn't exist
            $existingFileIncrement = 0
            Get-ChildItem -Path "$finalPath*.$Format" | Where-Object {
              if ($_.BaseName -Match '_([0-9]+)$') {
                [int]$i = [int]($Matches[1])
                if ($i -gt $existingFileIncrement) {
                  $existingFileIncrement = $i
                }
              }
            }
            $existingFileIncrement += 1
            $finalPath = "$($finalPath)_$($existingFileIncrement)"
          }
        }
        [System.IO.File]::Move("$workingPath.$Format", "$finalPath.$Format")
        $resultFile = [System.IO.FileInfo]"$finalPath.$Format"
      }
      default {
        $resultFile = [System.IO.DirectoryInfo]$finalPath
      }
    }
    $resultFile
    Write-Host "`nUWP Driver Pack created at $($resultFile.FullName)"
  }
}
# SIG # Begin signature block
# MIIoFwYJKoZIhvcNAQcCoIIoCDCCKAQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBunEcUokddUyud
# w2R6z1NyLrQk5qlFz4e2eTj021vKA6CCDYowggawMIIEmKADAgECAhAIrUCyYNKc
# TJ9ezam9k67ZMA0GCSqGSIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNV
# BAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yMTA0MjkwMDAwMDBaFw0z
# NjA0MjgyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
# ggIKAoICAQDVtC9C0CiteLdd1TlZG7GIQvUzjOs9gZdwxbvEhSYwn6SOaNhc9es0
# JAfhS0/TeEP0F9ce2vnS1WcaUk8OoVf8iJnBkcyBAz5NcCRks43iCH00fUyAVxJr
# Q5qZ8sU7H/Lvy0daE6ZMswEgJfMQ04uy+wjwiuCdCcBlp/qYgEk1hz1RGeiQIXhF
# LqGfLOEYwhrMxe6TSXBCMo/7xuoc82VokaJNTIIRSFJo3hC9FFdd6BgTZcV/sk+F
# LEikVoQ11vkunKoAFdE3/hoGlMJ8yOobMubKwvSnowMOdKWvObarYBLj6Na59zHh
# 3K3kGKDYwSNHR7OhD26jq22YBoMbt2pnLdK9RBqSEIGPsDsJ18ebMlrC/2pgVItJ
# wZPt4bRc4G/rJvmM1bL5OBDm6s6R9b7T+2+TYTRcvJNFKIM2KmYoX7BzzosmJQay
# g9Rc9hUZTO1i4F4z8ujo7AqnsAMrkbI2eb73rQgedaZlzLvjSFDzd5Ea/ttQokbI
# YViY9XwCFjyDKK05huzUtw1T0PhH5nUwjewwk3YUpltLXXRhTT8SkXbev1jLchAp
# QfDVxW0mdmgRQRNYmtwmKwH0iU1Z23jPgUo+QEdfyYFQc4UQIyFZYIpkVMHMIRro
# OBl8ZhzNeDhFMJlP/2NPTLuqDQhTQXxYPUez+rbsjDIJAsxsPAxWEQIDAQABo4IB
# WTCCAVUwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUaDfg67Y7+F8Rhvv+
# YXsIiGX0TkIwHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0P
# AQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGCCsGAQUFBwEBBGswaTAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAC
# hjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAcBgNVHSAEFTATMAcGBWeBDAED
# MAgGBmeBDAEEATANBgkqhkiG9w0BAQwFAAOCAgEAOiNEPY0Idu6PvDqZ01bgAhql
# +Eg08yy25nRm95RysQDKr2wwJxMSnpBEn0v9nqN8JtU3vDpdSG2V1T9J9Ce7FoFF
# UP2cvbaF4HZ+N3HLIvdaqpDP9ZNq4+sg0dVQeYiaiorBtr2hSBh+3NiAGhEZGM1h
# mYFW9snjdufE5BtfQ/g+lP92OT2e1JnPSt0o618moZVYSNUa/tcnP/2Q0XaG3Ryw
# YFzzDaju4ImhvTnhOE7abrs2nfvlIVNaw8rpavGiPttDuDPITzgUkpn13c5Ubdld
# AhQfQDN8A+KVssIhdXNSy0bYxDQcoqVLjc1vdjcshT8azibpGL6QB7BDf5WIIIJw
# 8MzK7/0pNVwfiThV9zeKiwmhywvpMRr/LhlcOXHhvpynCgbWJme3kuZOX956rEnP
# LqR0kq3bPKSchh/jwVYbKyP/j7XqiHtwa+aguv06P0WmxOgWkVKLQcBIhEuWTatE
# QOON8BUozu3xGFYHKi8QxAwIZDwzj64ojDzLj4gLDb879M4ee47vtevLt/B3E+bn
# KD+sEq6lLyJsQfmCXBVmzGwOysWGw/YmMwwHS6DTBwJqakAwSEs0qFEgu60bhQji
# WQ1tygVQK+pKHJ6l/aCnHwZ05/LWUpD9r4VIIflXO7ScA+2GRfS0YW6/aOImYIbq
# yK+p/pQd52MbOoZWeE4wggbSMIIEuqADAgECAhAGbBUteYe7OrU/9UuqLvGSMA0G
# CSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwHhcNMjQxMTA0MDAwMDAwWhcNMjUxMTAz
# MjM1OTU5WjBaMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTESMBAG
# A1UEBxMJUGFsbyBBbHRvMRAwDgYDVQQKEwdIUCBJbmMuMRAwDgYDVQQDEwdIUCBJ
# bmMuMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAhwvYomD82RHJaNe6
# hXdd082g5HbXVXhZD/0KKEfihtjmrlbGPRShWeEdNQuy+fJ8QWxwvBT2pxeSZgTU
# 7mF4Y6KywswKBs7BTypqoMeCRATSVeTbkqYrGQWR3Of/FJOmWDoXUoSQ+xpcBNx5
# c1VVWafuBjCTF63uA6oVjkZyJDX5+I8IV6XK9T8QIk73c66WPuG3/QExXuQDLRl9
# 7PgzAq0eduyiERUnvaMiTEKIjtyglzj33CI9b0N9ju809mjwCCX/JG1dyLFegKGD
# ckCBL4itfrX6QNmFXp3AvLJ4KkQw5KsZBFL4uvR7/Zkhp7ovO+DYlquRDQyD13de
# QketEgoxUXhRkALQbNCoIOfj3miEgYvOhtkc5Ody+tT+TTccp9D1EtKfn31hHtJi
# mbm1fQ5vUz+gEu7eDX8IBUu/3yonKjZwG3j337SKzTUJcrjBfteYMiyFf1hvnJ1Y
# YNG1NudpLCbz5Lg0T0oYNDtv/ZTH0rqt0V3kFTE2l+TJWE6NAgMBAAGjggIDMIIB
# /zAfBgNVHSMEGDAWgBRoN+Drtjv4XxGG+/5hewiIZfROQjAdBgNVHQ4EFgQUdIsz
# G4bM4goMS/SCP9csSmH2W2YwPgYDVR0gBDcwNTAzBgZngQwBBAEwKTAnBggrBgEF
# BQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5jb20vQ1BTMA4GA1UdDwEB/wQEAwIH
# gDATBgNVHSUEDDAKBggrBgEFBQcDAzCBtQYDVR0fBIGtMIGqMFOgUaBPhk1odHRw
# Oi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmlu
# Z1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNybDBToFGgT4ZNaHR0cDovL2NybDQuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNpZ25pbmdSU0E0MDk2U0hB
# Mzg0MjAyMUNBMS5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wXAYIKwYBBQUHMAKGUGh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNB
# NDA5NlNIQTM4NDIwMjFDQTEuY3J0MAkGA1UdEwQCMAAwDQYJKoZIhvcNAQELBQAD
# ggIBAGdZql3ql/27gF6v+IQZ/OT7MTSbokLTaIzd3ESqKnrbBmHPMGkGrynLVmyV
# 23O9o15tIUmyKqlbEjmqAnivgv7nUrpi4bUjvCoBuTWAtEkO+doAf7AxhUgS9Nl2
# zUtBLtuijJ2gorDnkB1+9LPsuraiRyiPHc2lo04pJEPzgo/o15+/VREr6vzkBBhw
# b7oyGiQocAlfPiUtL/9xlWSHUKnaUdLTfLjXIaDs2av1Z9c9tt9GpQLAS1Hbyfqj
# 6lyALau1X0XehqaN3O/O8rqd/is0jsginICErfhxZfhS/pbKuLOGaXDrk8bRmYUL
# StyhU148ktTgPBfcumuhuNACbcw8WZZnDcKnuzEoYJX6xsJi+jCHNh+zEyk3k+Xb
# c6e5DlwKqDsruFJVX3ATS1WQtW5mvpIxokIZuoST9D5errD3wNX5x5HinfSK+5FA
# QQ6DFLzftBxySkqq+flMYy/sI0KRnV00tFcgUnlqHVnidwsA3bVPDTy8fPGdNv+j
# pfbNfW4CCTOiV8gKCpEYyMcvcf5xV3TFOim4Hb4+PvVy1dwswFgFxJWUyEUI6OKL
# T67blyUDNRqqL7kXtn4XJvdKVjALkeUMZDHxfdaQ30TCtDRPHWpNskTH3F3aqNFM
# 8QVJxN0unuKdIbJiYJkldVgMyhT0I95EKSKsuLWK+VKUWu/MMYIZ4zCCGd8CAQEw
# fTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNV
# BAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hB
# Mzg0IDIwMjEgQ0ExAhAGbBUteYe7OrU/9UuqLvGSMA0GCWCGSAFlAwQCAQUAoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJ1uTGhS
# 9M7y+FIibckGjnltTaY/dxehQUixZjzN+QGrMA0GCSqGSIb3DQEBAQUABIIBgD4N
# StjkXox6VhjGsy4ReF/vkCORYP9IGSaypzFzb3CXkPMs9H0WNZ3ARBK3iHqB+LZL
# +xQcDSVIUkoOrwXx7XU+VDh8iDnLyPYJZ/T+YMDYiBu1ak6mh8QJvWfmkQZRZ3ao
# Z1rW2qD45tDK/wVOuHXwf8o6cP7OUOSsKTDEshXnb3oFLkXo35g2Q9FzXGutJKsG
# hZ48ydpQUARYbiT5KYJkKSDm4SZcZKPvJKlZHZyxUTUlNcBQ2kbSdrLStvJw+15u
# AnNTUFYwHlubKij9OQ0SMKQS74sT1VGaYrzKuvnV42C3rO3IYI33akZZzvRrUgqN
# 2EwEkZS7NvLjXrlzUS2v73MT/N2Bd4r1RBNbELr0PhuV5c30zKLqRI1FmHbV8ayk
# jOMtXfKwGMS/ZUAwf/Q9PrnzQAdL10lLF6lEkOUNmN47RT5C4jvA0HbdhvySPwlj
# QeYB231/kDK+NOYJpmlgY22vqw9u4l9UiZxZtIJDjjFUHf7qM2hHyAoewOWDPKGC
# Fzkwghc1BgorBgEEAYI3AwMBMYIXJTCCFyEGCSqGSIb3DQEHAqCCFxIwghcOAgED
# MQ8wDQYJYIZIAWUDBAIBBQAwdwYLKoZIhvcNAQkQAQSgaARmMGQCAQEGCWCGSAGG
# /WwHATAxMA0GCWCGSAFlAwQCAQUABCDN6DBt98hjGqMYB1G3dRHQDlPGDDb7preY
# n0NA5lYg/AIQFhycRTu4CfJtsnwnT2uVYBgPMjAyNTA0MTcxODQ4NTRaoIITAzCC
# BrwwggSkoAMCAQICEAuuZrxaun+Vh8b56QTjMwQwDQYJKoZIhvcNAQELBQAwYzEL
# MAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJE
# aWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBD
# QTAeFw0yNDA5MjYwMDAwMDBaFw0zNTExMjUyMzU5NTlaMEIxCzAJBgNVBAYTAlVT
# MREwDwYDVQQKEwhEaWdpQ2VydDEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1w
# IDIwMjQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC+anOf9pUhq5Yw
# ultt5lmjtej9kR8YxIg7apnjpcH9CjAgQxK+CMR0Rne/i+utMeV5bUlYYSuuM4vQ
# ngvQepVHVzNLO9RDnEXvPghCaft0djvKKO+hDu6ObS7rJcXa/UKvNminKQPTv/1+
# kBPgHGlP28mgmoCw/xi6FG9+Un1h4eN6zh926SxMe6We2r1Z6VFZj75MU/HNmtsg
# tFjKfITLutLWUdAoWle+jYZ49+wxGE1/UXjWfISDmHuI5e/6+NfQrxGFSKx+rDdN
# MsePW6FLrphfYtk/FLihp/feun0eV+pIF496OVh4R1TvjQYpAztJpVIfdNsEvxHo
# fBf1BWkadc+Up0Th8EifkEEWdX4rA/FE1Q0rqViTbLVZIqi6viEk3RIySho1XyHL
# IAOJfXG5PEppc3XYeBH7xa6VTZ3rOHNeiYnY+V4j1XbJ+Z9dI8ZhqcaDHOoj5KGg
# 4YuiYx3eYm33aebsyF6eD9MF5IDbPgjvwmnAalNEeJPvIeoGJXaeBQjIK13SlnzO
# DdLtuThALhGtyconcVuPI8AaiCaiJnfdzUcb3dWnqUnjXkRFwLtsVAxFvGqsxUA2
# Jq/WTjbnNjIUzIs3ITVC6VBKAOlb2u29Vwgfta8b2ypi6n2PzP0nVepsFk8nlcuW
# fyZLzBaZ0MucEdeBiXL+nUOGhCjl+QIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQD
# AgeAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0g
# BBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9z
# KXaaL3WMaiCPnshvMB0GA1UdDgQWBBSfVywDdw4oFZBmpWNe7k+SH3agWzBaBgNV
# HR8EUzBRME+gTaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEF
# BQcBAQSBgzCBgDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MFgGCCsGAQUFBzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRUcnVzdGVkRzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqG
# SIb3DQEBCwUAA4ICAQA9rR4fdplb4ziEEkfZQ5H2EdubTggd0ShPz9Pce4FLJl6r
# eNKLkZd5Y/vEIqFWKt4oKcKz7wZmXa5VgW9B76k9NJxUl4JlKwyjUkKhk3aYx7D8
# vi2mpU1tKlY71AYXB8wTLrQeh83pXnWwwsxc1Mt+FWqz57yFq6laICtKjPICYYf/
# qgxACHTvypGHrC8k1TqCeHk6u4I/VBQC9VK7iSpU5wlWjNlHlFFv/M93748YTeoX
# U/fFa9hWJQkuzG2+B7+bMDvmgF8VlJt1qQcl7YFUMYgZU1WM6nyw23vT6QSgwX5P
# q2m0xQ2V6FJHu8z4LXe/371k5QrN9FQBhLLISZi2yemW0P8ZZfx4zvSWzVXpAb9k
# 4Hpvpi6bUe8iK6WonUSV6yPlMwerwJZP/Gtbu3CKldMnn+LmmRTkTXpFIEB06nXZ
# rDwhCGED+8RsWQSIXZpuG4WLFQOhtloDRWGoCwwc6ZpPddOFkM2LlTbMcqFSzm4c
# d0boGhBq7vkqI1uHRz6Fq1IX7TaRQuR+0BGOzISkcqwXu7nMpFu3mgrlgbAW+Bzi
# kRVQ3K2YHcGkiKjA4gi4OA/kz1YCsdhIBHXqBzR0/Zd2QwQ/l4Gxftt/8wY3grcc
# /nS//TVkej9nmUYu83BDtccHHXKibMs/yXHhDXNkoPIdynhVAku7aRZOwqw6pDCC
# Bq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQELBQAwYjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0
# MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTepl1Gh1tKD
# 0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt+FeoAn39
# Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r07G1decf
# BmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dhgxndX7RU
# CyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfAcsW6Th+x
# tVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpHIEPjQ2OA
# e3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJSlRErWHRA
# KKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0z9JMq++b
# Pf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y99xh3pP+
# OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBIDfV8ju2Tj
# Y+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXTdrnSDmuZ
# DNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQW
# BBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/
# 57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYI
# KwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9j
# cmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1Ud
# IAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEA
# fVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoNqilp/GnB
# zx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8Vc40BIiXO
# lWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJodskr2dfNBw
# CnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6skHibBt94q
# 6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82HhyS7T6NJ
# uXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HNT7ZAmyEh
# QNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8zOYdBeHo4
# 6Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIXmVnKcPA3
# v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZE/6/pNHz
# V9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSFD/yYlvZV
# VCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPwwggWNMIIEdaADAgECAhAO
# mxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# JDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEw
# MDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxE
# aWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMT
# GERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprN
# rnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVy
# r2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4
# IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13j
# rclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4Q
# kXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQn
# vKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu
# 5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/
# 8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQp
# JYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFf
# xCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGj
# ggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/
# 57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8B
# Af8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2Nz
# cC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6
# oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEB
# AHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0a
# FPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNE
# m0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZq
# aVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCs
# WKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9Fc
# rBjDTZ9ztwGpn1eqXijiuZQxggN2MIIDcgIBATB3MGMxCzAJBgNVBAYTAlVTMRcw
# FQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3Rl
# ZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0ECEAuuZrxaun+Vh8b5
# 6QTjMwQwDQYJYIZIAWUDBAIBBQCggdEwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJ
# EAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MTcxODQ4NTRaMCsGCyqGSIb3DQEJEAIM
# MRwwGjAYMBYEFNvThe5i29I+e+T2cUhQhyTVhltFMC8GCSqGSIb3DQEJBDEiBCBO
# 7k90qd51qCJAHOT08MeWVZ8gf5BJqwc0b+0hTDf19jA3BgsqhkiG9w0BCRACLzEo
# MCYwJDAiBCB2dp+o8mMvH0MLOiMwrtZWdf7Xc9sF1mW5BZOYQ4+a2zANBgkqhkiG
# 9w0BAQEFAASCAgA4LKRbH9wHtOhhLsukfM4OavfrsgCHliYaDoWkgrBPK2lD+fyI
# A825qUHSe7VHOWa4wbouCcBgv0rxC5uG7TUHqhC6nlFOVzCB4cOvWktAb3UwSIeH
# ZrJroPji4T8912YTKxAJKAQDEqIk1LaxqPHE8H+N3vHYHti8bPFE/J8CVQWivcy2
# +z32l4fAhoLnBlIHHVs1Me/+tuhcf14Ktx9KWFi/f6t83GdRVsVmcgb0xCR3NSNs
# EMNWVMDtx65xO/kNyO1Jyss1TiCIelbgBWNcOaor2kq50RS4A7YiSVzo0+UVQI15
# ttGLQ4EFAp3NmDlhv9DFPFfQGHHhL/5t0IKKNaqnIAVNEnENrtf8xG2v7mWBio7S
# G2Flm2b2PzESTcua2fGL38KpvtDGLXB+YZbdbfSfdNhuUUkubDQLFet1MBTIBo2G
# FYdkOLIVz54jwhCyK7rJL4OZE+rlJ61mLWkCbMqoM7uQ1DWT9VsRE9p1k12BpfBl
# oa+CFiJcfB8xKcSjfei3mIaywLDIhlxXy1v43awNQA3HexqRuUK6BDcmfK9H0E36
# 3bkK552y0An5PYgFl8/B3hjNA2bBrFsnrASQPNAGxpw5w58WT5C0TLRs5bgY8kGi
# 4pjUrBjp6NUzzIVkVoFcFQGyVtjr3aCK+TXK7kQVUsa/MPDed3L6pji2Qw==
# SIG # End signature block
