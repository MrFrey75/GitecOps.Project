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

using namespace HP.CMSLHelper

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
#requires -Modules "HP.Private" 

# CMSL is normally installed in C:\Program Files\WindowsPowerShell\Modules
# but if installed via PSGallery and via PS7, it is installed in a different location
if (Test-Path "$PSScriptRoot\..\HP.Private\HP.CMSLHelper.dll") {
  Add-Type -Path "$PSScriptRoot\..\HP.Private\HP.CMSLHelper.dll"
}
else{
  Add-Type -Path "$PSScriptRoot\..\..\HP.Private\1.8.2\HP.CMSLHelper.dll"
}

[Flags()] enum DeprovisioningTarget{
  AgentProvisioning = 1
  OSImageProvisioning = 2
  ConfigurationData = 4
  TriggerRecoveryData = 8
  ScheduleRecoveryData = 16
}


# Converts a BIOS value to a boolean
function ConvertValue {
  param($value)
  if ($value -eq "Enable" -or $value -eq "Yes") { return $true }
  $false
}


<#
.SYNOPSIS
  Retrieves the current state of the HP Sure Recover feature

.DESCRIPTION
  This command retrieves the current state of the HP Sure Recover feature.

  Refer to the New-HPSureRecoverConfigurationPayload command for more information on how to configure HP Sure Recover.

.PARAMETER All
  If specified, the output includes the OS Recovery Image and the OS Recovery Agent configuration.

.NOTES
  - Requires HP BIOS with HP Sure Recover support.
  - This command requires elevated privileges.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK 
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.EXAMPLE
  Get-HPSureRecoverState
#>
function Get-HPSureRecoverState
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-HPSureRecoverState")]
  param([switch]$All)

  $mi_result = 0
  $data = New-Object -TypeName surerecover_state_t

  if ((Test-OSBitness) -eq 32){
    $result = [DfmNativeSureRecover]::get_surerecover_state32([ref]$data,[ref]$mi_result)
  }
  else {
    $result = [DfmNativeSureRecover]::get_surerecover_state64([ref]$data,[ref]$mi_result)
  }

  # $result is either E_DFM_SUCCESS = 0 or E_DFM_FAILED_WITH_EXTENDED_ERROR = 0x80000711
  # When $result is 0, $mi_result is also expected to be 0. Streamline the process by just checking $mi_result
  Test-HPPrivateCustomResult -result 0x80000711 -mi_result $mi_result -Category 0x05 -Verbose:$VerbosePreference

  $fixed_version = "$($data.subsystem_version[0]).$($data.subsystem_version[1])"
  if ($fixed_version -eq "0.0") {
    Write-Verbose "Patched SureRecover version 0.0 to 1.0"
    $fixed_version = "1.0"
  }
  $SchedulerIsDisabled = ($data.schedule.window_size -eq 0)

  $RecoveryTimeBetweenRetries = ([uint32]$data.os_flags -shr 8) -band 0x0f
  $RecoveryNumberOfRetries = ([uint32]$data.os_flags -shr 12) -band 0x07
  if ($RecoveryNumberOfRetries -eq 0)
  {
    $RecoveryNumberOfRetries = "Infinite"
  }
  $imageFailoverIsConfigured = [bool]$data.image_failover

  $obj = [ordered]@{
    Version = $fixed_version
    Nonce = $data.Nonce
    BIOSFlags = ($data.os_flags -band 0xff)
    ImageIsProvisioned = (($data.flags -band 2) -ne 0)
    AgentFlags = ($data.re_flags -band 0xffff)
    AgentIsProvisioned = (($data.flags -band 1) -ne 0)
    RecoveryTimeBetweenRetries = $RecoveryTimeBetweenRetries
    RecoveryNumberOfRetries = $RecoveryNumberOfRetries
    Schedule = New-Object -TypeName PSObject -Property @{
      DayOfWeek = $data.schedule.day_of_week
      hour = [uint32]$data.schedule.hour
      minute = [uint32]$data.schedule.minute
      WindowSize = [uint32]$data.schedule.window_size
    }
    ConfigurationDataIsProvisioned = (($data.flags -band 4) -ne 0)
    TriggerRecoveryDataIsProvisioned = (($data.flags -band 8) -ne 0)
    ScheduleRecoveryDataIsProvisioned = (($data.flags -band 16) -ne 0)
    SchedulerIsDisabled = $SchedulerIsDisabled
    ImageFailoverIsConfigured = $imageFailoverIsConfigured
  }

  if ($all.IsPresent)
  {
    $ia = [ordered]@{
      Url = (Get-HPBIOSSettingValue -Name "OS Recovery Image URL")
      Username = (Get-HPBIOSSettingValue -Name "OS Recovery Image Username")
      #PublicKey = (Get-HPBiosSettingValue -name "OS Recovery Image Public Key")
      ProvisioningVersion = (Get-HPBIOSSettingValue -Name "OS Recovery Image Provisioning Version")
    }

    $aa = [ordered]@{
      Url = (Get-HPBIOSSettingValue -Name "OS Recovery Agent URL")
      Username = (Get-HPBIOSSettingValue -Name "OS Recovery Agent Username")
      #PublicKey = (Get-HPBiosSettingValue -name "OS Recovery Agent Public Key")
      ProvisioningVersion = (Get-HPBIOSSettingValue -Name "OS Recovery Agent Provisioning Version")
    }

    $Image = New-Object -TypeName PSObject -Property $ia
    $Agent = New-Object -TypeName PSObject -Property $aa

    $obj.Add("Image",$Image)
    $osFailover = New-Object System.Collections.Generic.List[PSCustomObject]
    if ($imageFailoverIsConfigured) {
      try {
        $osFailoverIndex = Get-HPSureRecoverFailoverConfiguration -Image 'os'
        $osFailover.Add($osFailoverIndex)
      }
      catch {
        Write-Warning "Error reading OS Failover configuration $($Index): $($_.Exception.Message)"
      }
      $obj.Add("ImageFailover",$osFailover)
    }

    $obj.Add("Agent",$Agent)
  }
  return New-Object -TypeName PSCustomObject -Property $obj
}

<#
.SYNOPSIS
  Retrieves the current HP Sure Recover failover configuration

.DESCRIPTION
  This command retrieves the current configuration of the HP Sure Recover failover feature.

.PARAMETER Image
  Specifies whether this command will create a configuration payload for a Recovery Agent image or a Recovery OS image. However, only the value 'os' is supported for now.

.NOTES
  - Requires HP BIOS with HP Sure Recover and Failover support.
  - This command requires elevated privileges.

.EXAMPLE
  Get-HPSureRecoverFailoverConfiguration -Image os
#>
function Get-HPSureRecoverFailoverConfiguration
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-HPSureRecoverFailoverConfiguration")]
  param(
    [ValidateSet("os")]
    [Parameter(Mandatory = $false,Position = 0)]
    [string]$Image = 'os'
  )

  $mi_result = 0
  $data = New-Object -TypeName surerecover_failover_configuration_t
  $index = 1

  try {
    if((Test-OSBitness) -eq 32){
      $result = [DfmNativeSureRecover]::get_surerecover_failover_configuration32([bool]$False,[int]$index,[ref]$data,[ref]$mi_result)
    }
    else {
      $result = [DfmNativeSureRecover]::get_surerecover_failover_configuration64([bool]$False,[int]$index,[ref]$data,[ref]$mi_result)
    }

    Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x05 -Verbose:$VerbosePreference
  }
  catch {
    Write-Error "Failover is not configured properly. Error: $($_.Exception.Message)"
  }

  return [PSCustomObject]@{
    Index = $Index
    Version = $data.version
    Url = $data.url
    Username = $data.username
  }
}

<#
.SYNOPSIS
  Retrieves information about the HP Sure Recover embedded reimaging device

.DESCRIPTION
  This command retrieves information about the embedded reimaging device for HP Sure Recover.

.NOTES
  The embedded reimaging device is an optional hardware feature, and if not present, the field Embedded Reimaging Device is false.

.NOTES
  - Requires HP BIOS with HP Sure Recover support
  - Requires Embedded Reimaging device hardware option
  - This command requires elevated privileges.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.EXAMPLE
  Get-HPSureRecoverReimagingDeviceDetails
#>
function Get-HPSureRecoverReimagingDeviceDetails
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-HPSureRecoverReimagingDeviceDetails")]
  param()
  $result = @{}

  try {
    [string]$ImageVersion = Get-HPBIOSSettingValue -Name "OS Recovery Image Version"
    $result.Add("ImageVersion",$ImageVersion)
  }
  catch {}

  try {
    [string]$DriverVersion = Get-HPBIOSSettingValue -Name "OS Recovery Driver Version"
    $result.Add("DriverVersion",$DriverVersion)
  }
  catch {}

  try{
    # eMMC module is present if Embedded Storage for Recovery BIOS setting exists
    [string]$OSRsize = Get-HPBIOSSettingValue -Name "Embedded Storage for Recovery"
    $result.Add("EmbeddedReimagingDevice", $true)
  }
  catch{
    $result.Add("EmbeddedReimagingDevice", $false)
  }

  $result
}

<#
.SYNOPSIS
  Creates a payload to configure the HP Sure Recover OS or Recovery image

.DESCRIPTION
  This command creates a payload to configure a custom HP Sure Recover OS or Recovery image. There are three signing options to choose from:
  - Signing Key File (and Password) using -SigningKeyFile and -SigningKeyPassword parameters 
  - Signing Key Certificate using -SigningKeyCertificate parameter
  - Remote Signing using -RemoteSigningServiceKeyID and -RemoteSigningServiceURL parameters 

  Please note that using a Key File with Password in PFX format is recommended over using an X509 Certificate object because a private key in a certificate is not password protected.

  This command writes the created payload to the pipeline or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload command.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload. Creating the payload and passing it to the Set-HPSecurePlatformPayload command via the pipeline is not a recommended production pattern.

.PARAMETER Image
  Specifies whether this command will create a configuration payload for a Recovery Agent image or a Recovery OS image. The value must be either 'agent' or 'os'.

.PARAMETER SigningKeyFile
  Specifies the path to the Secure Platform Management signing key as a PFX file. If the PFX file is protected by a password (recommended), the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  Specifies the Secure Platform Management signing key file password, if required

.PARAMETER SigningKeyCertificate
  Specifies the Secure Platform Management signing key certificate as an X509Certificate object

.PARAMETER ImageCertificateFile
  Specifies the path to the image signing certificate as a PFX file. If the PFX file is protected by a password (recommended), the ImageCertificatePassword parameter should also be provided. Depending on the Image switch, this will be either the signing key file for the Agent or the OS image.
  ImageCertificateFile and PublicKeyFile are mutually exclusive.

.PARAMETER ImageCertificatePassword
  Specifies the image signing key file password, if required

.PARAMETER ImageCertificate
  Specifies the image signing key certificate as an X509Certificate object. Depending on the Image parameter, this value will be either the signing key certificate for the Agent or the OS image.

.PARAMETER PublicKeyFile
  Specifies the image signing key as the path to a base64-encoded RSA key (a PEM file).
  ImageCertificateFile and PublicKeyFile are mutually exclusive.

.PARAMETER PublicKey
  Specifies the image signing key as an array of bytes, including modulus and exponent.
  This option is currently reserved for internal use.

.PARAMETER Nonce
  Specifies a Nonce. If nonce is specified, the Secure Platform Management subsystem will only accept commands with a nonce greater or equal to the last nonce sent. This approach helps to prevent replay attacks. If not specified, the nonce is inferred from the current local time. The current local time as the nonce works in most cases. However, this approach has a resolution of seconds, so when performing parallel operations or a high volume of operations, it is possible for the same counter to be interpreted for more than one command. In these cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER Version
  Specifies the operation version. Each new configuration payload must increment the last operation payload version, as available in the public WMI setting 'OS Recovery Image Provisioning Version'. If this parameter is not provided, this command will read the public wmi setting and increment it automatically.

.PARAMETER Username
  Specifies the username for accessing the url specified in the Url parameter, if any.

.PARAMETER Password
  Specifies the password for accessing the url specified in the Url parameter, if any.

.PARAMETER Url
  Specifies the url from where to download the image. If not specified, the default HP.COM location will be used. 

.PARAMETER OutputFile
  Specifies the file to write output to instead of writing the output to the pipeline

.PARAMETER RemoteSigningServiceKeyID
  Specifies the Signing Key ID to be used

.PARAMETER RemoteSigningServiceURL
  Specifies the (Key Management Service) KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER CacheAccessToken
  If specified, the access token is cached in msalcache.dat file and user credentials will not be asked again until the credentials expire.
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server. 
  If access token is not cached, the user must re-enter credentials on each call of this command.

.NOTES
  - Requires HP BIOS with HP Sure Recover support 

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)  

.EXAMPLE
   $payload = New-HPSureRecoverImageConfigurationPayload -SigningKeyFile "$path\signing_key.pfx" -Image OS -ImageKeyFile  `
                 "$path\os.pfx" -username my_http_user -password `s3cr3t`  -url "http://my.company.com"
   ...
   $payload | Set-HPSecurePlatformPayload
#>
function New-HPSureRecoverImageConfigurationPayload
{
  [CmdletBinding(DefaultParameterSetName = "SKFileCert_OSFilePem",HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPSureRecoverImageConfigurationPayload")]
  param(
    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $true,Position = 0)]
    [ValidateSet("os","agent")]
    [string]$Image,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $true,Position = 1)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 2)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $true,Position = 3)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,


    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $true,Position = 1)]
    [Alias("ImageKeyFile")]
    [System.IO.FileInfo]$ImageCertificateFile,

    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 2)]
    [Alias("ImageKeyPassword")]
    [string]$ImageCertificatePassword,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $true,Position = 1)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$ImageCertificate,


    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $true,Position = 7)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $true,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $true,Position = 1)]
    [System.IO.FileInfo]$PublicKeyFile,


    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $true,Position = 8)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $true,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $true,Position = 1)]
    [byte[]]$PublicKey,


    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 2)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),


    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 3)]
    [uint16]$Version,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 4)]
    [string]$Username,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 12)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 5)]
    [string]$Password,

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 13)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 6)]
    [uri]$Url = "",

    [Parameter(ParameterSetName = "SKFileCert_OSBytesCert",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesCert",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKFileCert_OSFileCert",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFileCert",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKFileCert_OSBytesPem",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKBytesCert_OSBytesPem",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKFileCert_OSFilePem",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "SKBytesCert_OSFilePem",Mandatory = $false,Position = 14)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 7)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $true,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $true,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $true,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $true,Position = 8)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $true,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $true,Position = 10)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $true,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $true,Position = 9)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning_OSBytesCert",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFileCert",Mandatory = $false,Position = 11)]
    [Parameter(ParameterSetName = "RemoteSigning_OSBytesPem",Mandatory = $false,Position = 10)]
    [Parameter(ParameterSetName = "RemoteSigning_OSFilePem",Mandatory = $false,Position = 10)]
    [switch]$CacheAccessToken
  )

  Write-Verbose "Creating SureRecover Image provisioning payload"


  if ($PublicKeyFile -or $PublicKey) {
    $osk = Get-HPPrivatePublicKeyCoalesce -File $PublicKeyFile -key $PublicKey -Verbose:$VerbosePreference
  }
  else {
    $osk = Get-HPPrivateX509CertCoalesce -File $ImageCertificateFile -password $ImageCertificatePassword -cert $ImageCertificate -Verbose:$VerbosePreference
  }

  $OKBytes = $osk.Modulus

  $opaque = New-Object opaque4096_t
  $opaqueLength = 4096
  $mi_result = 0

  if (-not $Version) {
    if ($image -eq "os")
    {
      $Version = [uint16](Get-HPBIOSSettingValue "OS Recovery Image Provisioning Version") + 1
    }
    else {
      $Version = [uint16](Get-HPBIOSSettingValue "OS Recovery Agent Provisioning Version") + 1
    }
    Write-Verbose "New version number is $version"
  }

  if((Test-OSBitness) -eq 32){
    $result = [DfmNativeSureRecover]::get_surerecover_provisioning_opaque32($Nonce, $Version, $OKBytes,$($OKBytes.Count),$Username, $Password, $($Url.ToString()), [ref]$opaque, [ref]$opaqueLength,  [ref]$mi_result)
  }
  else {
    $result = [DfmNativeSureRecover]::get_surerecover_provisioning_opaque64($Nonce, $Version, $OKBytes,$($OKBytes.Count),$Username, $Password, $($Url.ToString()), [ref]$opaque, [ref]$opaqueLength,  [ref]$mi_result)
  }

  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x05

  $payload = $opaque.raw[0..($opaqueLength - 1)]

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning_OSBytesCert" -or $PSCmdlet.ParameterSetName -eq "RemoteSigning_OSFileCert" -or $PSCmdlet.ParameterSetName -eq "RemoteSigning_OSBytesPem" -or $PSCmdlet.ParameterSetName -eq "RemoteSigning_OSFilePem") {
    $sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference
    $sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }

  [byte[]]$out = $sig + $payload

  Write-Verbose "Building output document"
  $output = New-Object -TypeName PortableFileFormat
  $output.Data = $out

  if ($Image -eq "os") {
    $output.purpose = "hp:surerecover:provision:os_image"
  }
  else {
    $output.purpose = "hp:surerecover:provision:recovery_image"
  }

  Write-Verbose "Provisioning version will be $version"
  $output.timestamp = Get-Date

  if ($OutputFile) {
    Write-Verbose "Will output to file $OutputFile"
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    $output | ConvertTo-Json -Compress | Out-File -FilePath $f -Encoding utf8
  }
  else {
    $output | ConvertTo-Json -Compress
  }
}



<#
.SYNOPSIS
  Creates a payload to deprovision HP Sure Recover

.DESCRIPTION
  This command creates a payload to deprovision the HP Sure Recover feature. There are three signing options to choose from:
  - Signing Key File (and Password) using -SigningKeyFile and -SigningKeyPassword parameters 
  - Signing Key Certificate using -SigningKeyCertificate parameter
  - Remote Signing using -RemoteSigningServiceKeyID and -RemoteSigningServiceURL parameters 

  Please note that using a Key File with Password in PFX format is recommended over using an X509 Certificate object because a private key in a certificate is not password protected.

  This command writes the created payload to the pipeline or to the file specified in the OutputFile parameter. This payload can then be passed to the Set-HPSecurePlatformPayload command.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload command. Creating the payload and passing it to the Set-HPSecurePlatformPayload command via the pipeline is not a recommended production pattern.

.PARAMETER SigningKeyFile
  Specifies the path to the Secure Platform Management signing key as a PFX file. If the PFX file is protected by a password (recommended), the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  Specifies the Secure Platform Management signing key file password, if required.

.PARAMETER SigningKeyCertificate
  Specifies the Secure Platform Management signing key certificate as an X509Certificate object. 

.PARAMETER Nonce
  Specifies a Nonce. If nonce is specified, the Secure Platform Management subsystem will only accept commands with a nonce greater or equal to the last nonce sent. This approach helps to prevent replay attacks. If not specified, the nonce is inferred from the current local time. The current local time as the nonce works in most cases. However, this approach has a resolution of seconds, so when performing parallel operations or a high volume of operations, it is possible for the same counter to be interpreted for more than one command. In these cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER RemoveOnly
  This parameter allows deprovisioning only specific parts of the Sure Recover subsystem. If not specified, the entire SureRecover is deprovisoned. Possible values are one or more of the following:

  - AgentProvisioning   - remove the Agent provisioning
  - OSImageProvisioning - remove the OS Image provisioning
  - ConfigurationData - remove HP SureRecover configuration data 
  - TriggerRecoveryData - remove the HP Sure Recover trigger definition
  - ScheduleRecoveryData - remove the HP Sure Recover schedule definition

.PARAMETER OutputFile
    Specifies the file to write output to instead of writing the output to the pipelineing output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  Specifies the Signing Key ID to be used

.PARAMETER RemoteSigningServiceURL
  Specifies the (Key Management Service) KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER CacheAccessToken
  If specified, the access token is cached in msalcache.dat file and user credentials will not be asked again until the credentials expire.
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server. 
  If access token is not cached, the user must re-enter credentials on each call of this command.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with HP Sure Recover support

.EXAMPLE
  New-HPSureRecoverDeprovisionPayload -SigningKeyFile sk.pfx
#>
function New-HPSureRecoverDeprovisionPayload
{
  [CmdletBinding(DefaultParameterSetName = "SF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPSureRecoverDeprovisionPayload")]
  param(
    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [DeprovisioningTarget[]]$RemoveOnly,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 5)]
    [switch]$CacheAccessToken
  )

  Write-Verbose "Creating SureRecover deprovisioning payload"
  if ($RemoveOnly) {
    [byte]$target = 0
    $RemoveOnly | ForEach-Object { $target = $target -bor $_ }
    Write-Verbose "Will deprovision only $([string]$RemoveOnly)"
  }
  else
  {
    [byte]$target = 31 # all five bits
    Write-Verbose "No deprovisioning filter specified, will deprovision all SureRecover"
  }

  $payload = [BitConverter]::GetBytes($nonce) + $target

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference
    $sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }

  Write-Verbose "Building output document"
  $output = New-Object -TypeName PortableFileFormat
  $output.Data = $sig + $payload
  $output.purpose = "hp:surerecover:deprovision"
  $output.timestamp = Get-Date

  if ($OutputFile) {
    Write-Verbose "Will output to file $OutputFile"
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    $output | ConvertTo-Json -Compress | Out-File -FilePath $f -Encoding utf8
  }
  else {
    $output | ConvertTo-Json -Compress
  }
}



<#
.SYNOPSIS
    Creates a payload to configure the HP Sure Recover schedule

.DESCRIPTION
  This command creates a payload to configure a HP Sure Recover schedule. There are three signing options to choose from:
  - Signing Key File (and Password) using -SigningKeyFile and -SigningKeyPassword parameters 
  - Signing Key Certificate using -SigningKeyCertificate parameter
  - Remote Signing using -RemoteSigningServiceKeyID and -RemoteSigningServiceURL parameters 
  
  Please note that using a Key File with Password in PFX format is recommended over using an X509 Certificate object because a private key in a certificate is not password protected.

  This command writes the created payload to the pipeline or to the file specified in the OutputFile parameter. This payload can then be passed to the Set-HPSecurePlatformPayload command.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload command. Creating the payload and passing it to the Set-HPSecurePlatformPayload command via the pipeline is not a recommended production pattern.

.PARAMETER SigningKeyFile
  Specifies the path to the Secure Platform Management signing key, as a PFX file. If the PFX file is protected by a password (recommended),
  the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  Specifies the Secure Platform Management signing key file password, if required.

.PARAMETER SigningKeyCertificate
  Specifies the Secure Platform Management signing key certificate, as an X509Certificate object. 

.PARAMETER Nonce
  Specifies a Nonce. If nonce is specified, the Secure Platform Management subsystem will only accept commands with a nonce greater or equal to the last nonce sent. This approach helps to prevent replay attacks. If not specified, the nonce is inferred from the current local time. The current local time as the nonce works in most cases. However, this approach has a resolution of seconds, so when performing parallel operations or a high volume of operations, it is possible for the same counter to be interpreted for more than one command. In these cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER DayOfWeek
  Specifies the day of the week for the schedule

.PARAMETER Hour
  Specifies the hour value for the schedule

.PARAMETER Minute
  Specifies the minute of the schedule

.PARAMETER WindowSize
  Specifies the windows size for the schedule activation in minutes, in case the exact configured schedule is
  missed. By default, the window is zero. The value may not be larger than 240 minutes (4 hours).

.PARAMETER Disable
  If specified, this command creates a payload to disable HP Sure Recover schedule.

.PARAMETER OutputFile
  Specifies the file to write output to instead of writing the output to the pipelineing output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  Specifies the Signing Key ID to be used

.PARAMETER RemoteSigningServiceURL
  Specifies the (Key Management Service) KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER CacheAccessToken
  If specified, the access token is cached in msalcache.dat file and user credentials will not be asked again until the credentials expire.
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server. 
  If access token is not cached, the user must re-enter credentials on each call of this command.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with HP Sure Recover support

.EXAMPLE
  New-HPSureRecoverSchedulePayload -SigningKeyFile sk.pfx -DayOfWeek Sunday -Hour 2

.EXAMPLE
  New-HPSureRecoverSchedulePayload -SigningKeyFile sk.pfx -Disable
#>
function New-HPSureRecoverSchedulePayload
{
  [CmdletBinding(DefaultParameterSetName = "SF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPSureRecoverSchedulePayload")]
  param(

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "DisableSF",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ValueFromPipeline,ParameterSetName = "SB",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "DisableSB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "DisableSF",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [Parameter(ParameterSetName = "DisableRemoteSigning",Mandatory = $false,Position = 0)]
    [Parameter(ParameterSetName = "DisableSF",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "DisableSB",Mandatory = $false,Position = 1)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 1)]
    [surerecover_day_of_week]$DayOfWeek = [surerecover_day_of_week]::Sunday,

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 2)]
    [ValidateRange(0,23)]
    [uint32]$Hour = 0,

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [ValidateRange(0,59)]
    [uint32]$Minute = 0,

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [ValidateRange(1,240)]
    [uint32]$WindowSize = 0,

    [Parameter(ParameterSetName = "DisableRemoteSigning",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "DisableSF",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "DisableSB",Mandatory = $true,Position = 2)]
    [switch]$Disable,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "DisableRemoteSigning",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "DisableSF",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "DisableSB",Mandatory = $false,Position = 3)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "DisableRemoteSigning",Mandatory = $true,Position = 3)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 7)]
    [Parameter(ParameterSetName = "DisableRemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "DisableRemoteSigning",Mandatory = $false,Position = 5)]
    [switch]$CacheAccessToken
  )

  Write-Verbose "Creating SureRecover scheduling payload"
  $schedule_data = New-Object -TypeName surerecover_schedule_data_t

  Write-Verbose "Will set the SureRecover scheduler"
  $schedule_data.day_of_week = $DayOfWeek
  $schedule_data.hour = $Hour
  $schedule_data.minute = $Minute
  $schedule_data.window_size = $WindowSize

  $schedule = New-Object -TypeName surerecover_schedule_data_payload_t
  $schedule.schedule = $schedule_data
  $schedule.Nonce = $Nonce

  $cmd = New-Object -TypeName surerecover_schedule_payload_t
  $cmd.Data = $schedule
  [byte[]]$payload = (Convert-HPPrivateObjectToBytes -obj $schedule -Verbose:$VerbosePreference)[0]

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning" -or $PSCmdlet.ParameterSetName -eq "DisableRemoteSigning") {
    $cmd.sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate -Verbose:$VerbosePreference
    $cmd.sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }

  Write-Verbose "Building output document"
  $output = New-Object -TypeName PortableFileFormat

  $output.Data = (Convert-HPPrivateObjectToBytes -obj $cmd -Verbose:$VerbosePreference)[0]
  $output.purpose = "hp:surerecover:scheduler"
  $output.timestamp = Get-Date


  if ($OutputFile) {
    Write-Verbose "Will output to file $OutputFile"
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    $output | ConvertTo-Json -Compress | Out-File -FilePath $f -Encoding utf8
  }
  else {
    $output | ConvertTo-Json -Compress
  }
}


<#
.SYNOPSIS
  Creates a payload to configure HP Sure Recover

.DESCRIPTION
  This command create a payload to configure HP Sure Recover. There are three signing options to choose from:
  - Signing Key File (and Password) using -SigningKeyFile and -SigningKeyPassword parameters 
  - Signing Key Certificate using -SigningKeyCertificate parameter
  - Remote Signing using -RemoteSigningServiceKeyID and -RemoteSigningServiceURL parameters 

  Please note that using a Key File with Password in PFX format is recommended over using an X509 Certificate object because a private key in a certificate is not password protected.

  This command writes the created payload to the pipeline or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload command.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload command. Creating the payload and passing it to the Set-HPSecurePlatformPayload command via the pipeline is not a recommended production pattern.

.PARAMETER SigningKeyFile
  Specifies the path to the Secure Platform Management signing key as a PFX file. If the PFX file is protected by a password (recommended), the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  Specifies the Secure Platform Management signing key file password, if required.

.PARAMETER SigningKeyCertificate
  Specifies the Secure Platform Management signing key certificate as an X509Certificate object.

.PARAMETER SigningKeyModulus
  The Secure Platform Management signing key modulus

.PARAMETER Nonce
  Specifies a Nonce. If nonce is specified, the Secure Platform Management subsystem will only accept commands with a nonce greater or equal to the last nonce sent. This approach helps to prevent replay attacks. If not specified, the nonce is inferred from the current local time. The current local time as the nonce works in most cases. However, this approach has a resolution of seconds, so when performing parallel operations or a high volume of operations, it is possible for the same counter to be interpreted for more than one command. In these cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER BIOSFlags
  Specifies the imaging flags to set. Please note that this parameter was previously named OSImageFlags.
  None = 0 
  NetworkBasedRecovery = 1 => Enable network based recovery
  WiFi = 2 => Enable WiFi
  PartitionRecovery = 4 => Enable partition based recovery
  SecureStorage = 8 => Enable recovery from secure storage device
  SecureEraseUnit = 16 => Secure Erase Unit before recovery
  RollbackPrevention = 64 => Enforce rollback prevention 

.PARAMETER AgentFlags
  Specifies the agent flags to set:
  None = 0 => OEM OS release with in-box drivers
  DRDVD = 1 => OEM OS release with optimized drivers 
  CorporateReadyWithoutOffice = 2 => Corporate ready without office
  CorporateReadyWithOffice = 4 => Corporate ready with office
  InstallManageabilitySuite = 16 => Install current components of the Manageability Suite included on the DRDVD
  InstallSecuritySuite = 32 => Install current components of the Security Suite included on the DRDVD 
  RollbackPrevention = 64 => Enforce rollback prevention
  EnableOSUpgrade = 256 => Enable OS upgrade with approproiate DPK 
  Please note that the Image Type AgentFlags DRDVD, CorporateReadyWithOffice, and CorporateReadyWithoutOffice are mutually exclusive. If you choose to set an Image type flag, you can only set one of the three flags.

.PARAMETER OutputFile
  Specifies the file to write output to instead of writing the output to the pipelineing output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  Specifies the Signing Key ID to be used

.PARAMETER RemoteSigningServiceURL
  Specifies the (Key Management Service) KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER CacheAccessToken
  If specified, the access token is cached in msalcache.dat file and user credentials will not be asked again until the credentials expire.
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server. 
  If access token is not cached, the user must re-enter credentials on each call of this command.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with HP Sure Recover support

.EXAMPLE
  New-HPSureRecoverConfigurationPayload -SigningKeyFile sk.pfx -BIOSFlags WiFi -AgentFlags DRDVD

.EXAMPLE
  New-HPSureRecoverConfigurationPayload -SigningKeyFile sk.pfx -BIOSFlags WiFi,SecureStorage -AgentFlags DRDVD,RollbackPrevention
#>
function New-HPSureRecoverConfigurationPayload
{
  [CmdletBinding(DefaultParameterSetName = "SF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPSureRecoverConfigurationPayload")]
  param(

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ValueFromPipeline,ParameterSetName = "SB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 1)]
    [Alias("OSImageFlags")]
    [surerecover_os_flags_no_reserved]$BIOSFlags, # does not allow setting to reserved values

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 2)]
    [surerecover_re_flags_no_reserved]$AgentFlags, # does not allow setting to reserved values

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 5)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [switch]$CacheAccessToken
  )

  # Image Type AgentFlags DRDVD, CorporateReadyWithOffice. and CorporateReadyWithoutOffice are all mutually exclusive 
  # as only one of the three is valid at a time
  if ($AgentFlags -band 1 -and ($AgentFlags -band 2 -or $AgentFlags -band 4) -or
      $AgentFlags -band 2 -and ($AgentFlags -band 1 -or $AgentFlags -band 4) -or
      $AgentFlags -band 4 -and ($AgentFlags -band 1 -or $AgentFlags -band 2)){
    throw "Cannot set multiple Image Type AgentFlags: DRDVD, CorporateReadyWithOffice, and CorporateReadyWithoutOffice are mutually exclusive."
  }
  
  # surerecover_configuration_payload_t has flags enums with reserved values, 
  # but since the parameter validation ensures user cannot select reserved values to set, 
  # we can safely cast the values to uint32 to be used in the payload with reserved values
  $data = New-Object -TypeName surerecover_configuration_payload_t
  $data.os_flags = [uint32]$BIOSFlags
  $data.re_flags = [uint32]$AgentFlags
  $data.arp_counter = $Nonce

  $cmd = New-Object -TypeName surerecover_configuration_t
  $cmd.Data = $data

  [byte[]]$payload = (Convert-HPPrivateObjectToBytes -obj $data -Verbose:$VerbosePreference)[0]

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $cmd.sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate
    $cmd.sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }

  Write-Verbose "Building output document"
  $output = New-Object -TypeName PortableFileFormat
  $output.Data = (Convert-HPPrivateObjectToBytes -obj $cmd -Verbose:$VerbosePreference)[0]
  $output.purpose = "hp:surerecover:configure"
  $output.timestamp = Get-Date

  if ($OutputFile) {
    Write-Verbose "Will output to file $OutputFile"
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    $output | ConvertTo-Json -Compress | Out-File -FilePath $f -Encoding utf8
  }
  else {
    $output | ConvertTo-Json -Compress
  }
}

<#
.SYNOPSIS
  Creates a payload to configure HP Sure Recover OS or Recovery image failover

.DESCRIPTION
  This command creates a payload to configure HP Sure Recover OS or Recovery image failover. There are three signing options to choose from:
  - Signing Key File (and Password) using -SigningKeyFile and -SigningKeyPassword parameters 
  - Signing Key Certificate using -SigningKeyCertificate parameter
  - Remote Signing using -RemoteSigningServiceKeyID and -RemoteSigningServiceURL parameters 

  Please note that using a Key File with Password in PFX format is recommended over using an X509 Certificate object because a private key in a certificate is not password protected.

  This command writes the created payload to the pipeline or to the file specified in the OutputFile parameter. This payload can then be passed to the Set-HPSecurePlatformPayload command.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload command. Creating the payload and passing it to the Set-HPSecurePlatformPayload command via the pipeline is not a recommended production pattern.

.PARAMETER Image
  Specifies whether this command will create a configuration payload for a Recovery Agent image or a Recovery OS  image. For now, only 'os' is supported.

.PARAMETER SigningKeyFile
  Specifies the path to the Secure Platform Management signing key, as a PFX file. If the PFX file is protected by a password (recommended),
  the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  Specifies the Secure Platform Management signing key file password, if required.

.PARAMETER SigningKeyCertificate
  Specifies the Secure Platform Management signing key certificate as an X509Certificate object.

.PARAMETER Version
  Specifies the operation version. Each new configuration payload must increment the last operation payload version, as available in the Get-HPSureRecoverFailoverConfiguration. If this parameter is not provided, this command will read from current system and increment it automatically.

.PARAMETER Username
  Specifies the username for accessing the url specified in the Url parameter, if any.

.PARAMETER Password
  Specifies the password for accessing the url specified in the Url parameter, if any.

.PARAMETER Url
  Specifies the URL from where to download the image. An empty URL can be specified to deprovision Failover.

.PARAMETER Nonce
  Specifies a Nonce. If nonce is specified, the Secure Platform Management subsystem will only accept commands with a nonce greater or equal to the last nonce sent. This approach helps to prevent replay attacks. If not specified, the nonce is inferred from the current local time. The current local time as the nonce works in most cases. However, this approach has a resolution of seconds, so when performing parallel operations or a high volume of operations, it is possible for the same counter to be interpreted for more than one command. In these cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER OutputFile
  Specifies the file to write output to instead of writing the output to the pipelineing output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  Specifies the Signing Key ID to be used

.PARAMETER RemoteSigningServiceURL
  Specifies the (Key Management Service) KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/). This URL must be HTTPS. 

.PARAMETER CacheAccessToken
  If specified, the access token is cached in msalcache.dat file and user credentials will not be asked again until the credentials expire.
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server. 
  If access token is not cached, the user must re-enter credentials on each call of this command.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with HP Sure Recover support

.EXAMPLE
  New-HPSureRecoverFailoverConfigurationPayload -SigningKeyFile sk.pfx -Version 1 -Url ''

.EXAMPLE
  New-HPSureRecoverFailoverConfigurationPayload -SigningKeyFile sk.pfx -Image os -Version 1 -Nonce 2 -Url 'http://url.com/' -Username 'user' -Password 123
#>
function New-HPSureRecoverFailoverConfigurationPayload
{
  [CmdletBinding(DefaultParameterSetName = "SF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPSureRecoverFailoverConfigurationPayload")]
  param(

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ValueFromPipeline,ParameterSetName = "SB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [ValidateSet("os")]
    [string]$Image = "os",

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [uint16]$Version,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [string]$Username,

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [string]$Password,

    [Parameter(ParameterSetName = "SF",Mandatory = $true,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $true,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [uri]$Url = "",

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 5)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SF",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SB",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 7)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 8)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 9)]
    [switch]$CacheAccessToken
  )

  if (-not $Version) {
    try {
      $Version = (Get-HPSureRecoverFailoverConfiguration -Image $Image).Version + 1
    }
    catch {
      # It is not possible to get current version if failover is not configured yet, assigning version 1
      $Version = 1
    }
    Write-Verbose "New version number is $version"
  }

  $opaque = New-Object opaque4096_t
  $opaqueLength = 4096
  $mi_result = 0
  [byte]$index = 1

  if((Test-OSBitness) -eq 32){
    $result = [DfmNativeSureRecover]::get_surerecover_failover_opaque32($Nonce, $Version, $index, $Username, $Password, $($Url.ToString()), [ref]$opaque, [ref]$opaqueLength, [ref]$mi_result);
  }
  else {
    $result = [DfmNativeSureRecover]::get_surerecover_failover_opaque64($Nonce, $Version, $index, $Username, $Password, $($Url.ToString()), [ref]$opaque, [ref]$opaqueLength, [ref]$mi_result);
  }

  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x05

  [byte[]]$payload = $opaque.raw[0..($opaqueLength - 1)]

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    $sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeycertificate
    $sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }

  [byte[]]$out = $sig + $payload

  Write-Verbose "Building output document"
  $output = New-Object -TypeName PortableFileFormat
  $output.Data = $out
  $output.purpose = "hp:surerecover:failover:os_image"
  $output.timestamp = Get-Date

  if ($OutputFile) {
    Write-Verbose "Will output to file $OutputFile"
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    $output | ConvertTo-Json -Compress | Out-File -FilePath $f -Encoding utf8
  }
  else {
    $output | ConvertTo-Json -Compress
  }

}

<#
.SYNOPSIS
  Creates a payload to trigger HP Sure Recover events

.DESCRIPTION
  This command creates a payload to trigger HP Sure Recover. There are three signing options to choose from:
  - Signing Key File (and Password) using -SigningKeyFile and -SigningKeyPassword parameters 
  - Signing Key Certificate using -SigningKeyCertificate parameter
  - Remote Signing using -RemoteSigningServiceKeyID and -RemoteSigningServiceURL parameters 

  Please note that using a Key File with Password in PFX format is recommended over using an X509 Certificate object because a private key in a certificate is not password protected.

  This command writes the created payload to the pipeline or to the file specified in the OutputFile parameter. This payload can then be passed to the Set-HPSecurePlatformPayload command.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload command. Creating the payload and passing it to the Set-HPSecurePlatformPayload command via the pipeline is not a recommended production pattern.

.PARAMETER SigningKeyFile
  Specifies the path to the Secure Platform Management signing key as a PFX file. If the PFX file is protected by a password (recommended), the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyPassword
  Specifies the Secure Platform Management signing key file password, if required.

.PARAMETER SigningKeyCertificate
  Specifies the Secure Platform Management signing key certificate as an X509Certificate object

.PARAMETER Nonce
  Specifies a Nonce. If nonce is specified, the Secure Platform Management subsystem will only accept commands with a nonce greater or equal to the last nonce sent. This approach helps to prevent replay attacks. If not specified, the nonce is inferred from the current local time. The current local time as the nonce works in most cases. However, this approach has a resolution of seconds, so when performing parallel operations or a high volume of operations, it is possible for the same counter to be interpreted for more than one command. In these cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER Set
  If specified, this command sets the trigger information. This parameter is used by default and optional.

.PARAMETER Cancel
  If specified, this command clears any existing trigger definition.

.PARAMETER ForceAfterReboot
  Specifies how many reboots to count before applying the trigger. If not specified, the value defaults to 1 (next reboot).    

.PARAMETER PromptPolicy
  Specifies the prompting policy. If not specified, it will default to prompt before recovery, and on error.

.PARAMETER ErasePolicy
  Specifies the erase policy for the imaging process

.PARAMETER OutputFile
  Specifies the file to write output to instead of writing the output to the pipelineing output to the specified file, instead of writing it to the pipeline.

.PARAMETER RemoteSigningServiceKeyID
  Specifies the Signing Key ID to be used

.PARAMETER RemoteSigningServiceURL
  Specifies the (Key Management Service) KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/)

.PARAMETER CacheAccessToken
  If specified, the access token is cached in msalcache.dat file and user credentials will not be asked again until the credentials expire.
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server. 
  If access token is not cached, the user must re-enter credentials on each call of this command.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with HP Sure Recover support

.EXAMPLE
  New-HPSureRecoverTriggerRecoveryPayload -SigningKeyFile sk.pfx
#>
function New-HPSureRecoverTriggerRecoveryPayload
{
  [CmdletBinding(DefaultParameterSetName = "SF_Schedule",HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPSureRecoverTriggerRecoveryPayload")]
  param(

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "SF_Cancel",Mandatory = $true,Position = 0)]
    [string]$SigningKeyFile,

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "SF_Cancel",Mandatory = $false,Position = 1)]
    [string]$SigningKeyPassword,

    [Parameter(ValueFromPipeline,ParameterSetName = "SB_Schedule",Mandatory = $true,Position = 0)]
    [Parameter(ValueFromPipeline,ParameterSetName = "SB_Cancel",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SF_Cancel",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "SB_Cancel",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 0)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $false,Position = 0)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 1)]
    [switch]$Set,

    [Parameter(ParameterSetName = "SF_Cancel",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "SB_Cancel",Mandatory = $true,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $true,Position = 1)]
    [switch]$Cancel,

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 2)]
    [ValidateRange(1,7)]
    [byte]$ForceAfterReboot = 1,

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 3)]
    [surerecover_prompt_policy]$PromptPolicy = "PromptBeforeRecovery,PromptOnError",

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 4)]
    [surerecover_erase_policy]$ErasePolicy = "None",

    [Parameter(ParameterSetName = "SF_Schedule",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SB_Schedule",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SF_Cancel",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "SB_Cancel",Mandatory = $false,Position = 9)]
    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $false,Position = 2)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $true,Position = 6)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $true,Position = 3)]
    [string]$RemoteSigningServiceKeyID,

    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $true,Position = 7)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning_Schedule",Mandatory = $false,Position = 8)]
    [Parameter(ParameterSetName = "RemoteSigning_Cancel",Mandatory = $false,Position = 5)]
    [switch]$CacheAccessToken
  )

  $data = New-Object -TypeName surerecover_trigger_payload_t
  $data.arp_counter = $Nonce
  $data.bios_trigger_flags = 0

  $output = New-Object -TypeName PortableFileFormat

  if ($Cancel.IsPresent)
  {
    Write-Verbose "Creating payload to cancel trigger"
    $output.purpose = "hp:surerecover:trigger"
    $data.bios_trigger_flags = 0
    $data.re_trigger_flags = 0
  }
  else {
    Write-Verbose ("Creating payload to set trigger")
    $output.purpose = "hp:surerecover:trigger"
    $data.bios_trigger_flags = [uint32]$ForceAfterReboot
    $data.re_trigger_flags = [uint32]$PromptPolicy
    $data.re_trigger_flags = ([uint32]$ErasePolicy -shl 4) -bor $data.re_trigger_flags
  }

  $cmd = New-Object -TypeName surerecover_trigger_t
  $cmd.Data = $data

  [byte[]]$payload = (Convert-HPPrivateObjectToBytes -obj $data -Verbose:$VerbosePreference)[0]

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning_Schedule" -or $PSCmdlet.ParameterSetName -eq "RemoteSigning_Cancel") {
    $cmd.sig = Invoke-HPPrivateRemoteSignData -Data $payload -CertificateId $RemoteSigningServiceKeyID -KMSUri $RemoteSigningServiceURL -CacheAccessToken:$CacheAccessToken -Verbose:$VerbosePreference
  }
  elseif ($SigningKeyCertificate){
    $sk = Get-HPPrivateX509CertCoalesce -cert $SigningKeyCertificate -Verbose:$VerbosePreference
    $cmd.sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }
  else {
    $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -Verbose:$VerbosePreference
    $cmd.sig = Invoke-HPPrivateSignData -Data $payload -Certificate $sk.Full -Verbose:$VerbosePreference
  }

  Write-Verbose "Building output document with nonce $([BitConverter]::GetBytes($nonce))"

  $output.Data = (Convert-HPPrivateObjectToBytes -obj $cmd -Verbose:$VerbosePreference)[0]
  Write-Verbose "Sending document of size $($output.data.length)"
  $output.timestamp = Get-Date

  if ($OutputFile) {
    Write-Verbose "Will output to file $OutputFile"
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    $output | ConvertTo-Json -Compress | Out-File -FilePath $f -Encoding utf8
  }
  else {
    $output | ConvertTo-Json -Compress
  }
}


<#
.SYNOPSIS
  Invokes the WMI command to trigger the BIOS to perform a service event on the next boot

.DESCRIPTION
  This command invokes the WMI command to trigger the BIOS to perform a service event on the next boot. If the hardware option is not present, this command will throw a NotSupportedException exception. 

  The BIOS will then compare SR_AED to HP_EAD and agent will compare SR_Image to HP_Image and update as necessary. The CloudRecovery.exe is the tool that performs the actual update.

.LINK 
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.LINK
  [Blog post: Provisioning and Configuring HP Sure Recover with HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/provisioning-and-configuring-hp-sure-recover-hp-client-management-script-library)
  
  
.NOTES
  - Requires HP BIOS with HP Sure Recover support
  - Requires Embedded Reimaging device hardware option

.EXAMPLE
  Invoke-HPSureRecoverTriggerUpdate
#>
function Invoke-HPSureRecoverTriggerUpdate
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Invoke-HPSureRecoverTriggerUpdate")]
  param()

  $mi_result = 0

  if((Test-OSBitness) -eq 32){
    $result = [DfmNativeSureRecover]::raise_surerecover_service_event_opaque32($null, $null, [ref]$mi_result)
  }
  else{
    $result = [DfmNativeSureRecover]::raise_surerecover_service_event_opaque64($null, $null, [ref]$mi_result)
  }

  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x05
}


# SIG # Begin signature block
# MIIoFwYJKoZIhvcNAQcCoIIoCDCCKAQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDm2GbUjL1gLWwp
# yMXYd/+fPQHi1ixEf+oBaOvVDJFZCqCCDYowggawMIIEmKADAgECAhAIrUCyYNKc
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGoejluS
# 2A8Ojydt08br/PmnoDZ8pn5P6QkoYF0o5+G5MA0GCSqGSIb3DQEBAQUABIIBgF7o
# Gv6MtmPyUSJWJsvWEgW+7gGsa7QLJMXhIR84uIaDAZqBOHv4p8e19rzmT8e9o5wL
# FxwNuXcc/rPZrMQFqvQZWM0sqOFQDHS7GqcYZ5NoRvakextyptlyA+P0nlE6qcSM
# mTxYN7H5xRCQZa0QZzAM0mzC1waE49t8BdKGR54Qq4HcTIqH037vSNa8FADOOPu2
# W93XjvRbG2v7kdug+rAkWITsFrI0HPTMmquEwkefv2nE0U7R/IuCspyi/Ra0xrut
# Qc8piA1PJp0dO6AgYLM0G7WW+T45xlBhrRxROR8q7BrSUuK8JbS1ScfmCYRRzg4u
# KS2kF2Rw8RQUlZ4o/Ir1n39E5cf7QqFQHU131haoEHbab0P9lhhjBp0oRsVwrZzu
# 0k5I6gopnU3HUDrWeA6gDwhbbsjByAhmrYvXIAox8PyyanU40RRNSyK8ItTnsBfu
# UOEQzSsU+TWZOcu7Vz9FqFyTdB6vvG1TXm3+cLoNU+w9zsu1HaWWGkOFZ1oWCaGC
# Fzkwghc1BgorBgEEAYI3AwMBMYIXJTCCFyEGCSqGSIb3DQEHAqCCFxIwghcOAgED
# MQ8wDQYJYIZIAWUDBAIBBQAwdwYLKoZIhvcNAQkQAQSgaARmMGQCAQEGCWCGSAGG
# /WwHATAxMA0GCWCGSAFlAwQCAQUABCCD+Jr+AToP7IGJtTKVrSh0lDtzOTsMQ+YF
# xTzo9Tjy+QIQHWj/m134Lj4S53E1d230fhgPMjAyNTA0MTcxODQ4NDZaoIITAzCC
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
# EAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MTcxODQ4NDZaMCsGCyqGSIb3DQEJEAIM
# MRwwGjAYMBYEFNvThe5i29I+e+T2cUhQhyTVhltFMC8GCSqGSIb3DQEJBDEiBCAP
# PL6sAIkZNLtppphjywn3Piz+a7nk/m/3hw+y5yKrbzA3BgsqhkiG9w0BCRACLzEo
# MCYwJDAiBCB2dp+o8mMvH0MLOiMwrtZWdf7Xc9sF1mW5BZOYQ4+a2zANBgkqhkiG
# 9w0BAQEFAASCAgAwgLQ5cqC7PbrU9phCgb6xyQIuiCDRmNVP4SV9OobFyRY/UH8N
# S4uuqXcZ3vXRVi5t+zO2S64eMCycNzNPLejufYG7pk0GGWLgVbfCLs+O0Nnjj20f
# XD1a2bxi+xtaUx4oTfii3mvTwzmReMAZCR1CUJOZIsMnK1JvV6NPgwEiqnr0/iml
# +wOYUxP/lz+1CKpInbLlCo4QfllWKOMj3s8du0YBpAxSzq90XXK9eYhZ5OUw+aek
# uoOB3xkPhRr1XkEBFuDudsuAg7mTQEInKPUXHg9hl+RYADRMrB5oYNK6FusjDklP
# 2LGTmkwDz3QEStK8fIRwLd/GaOWFGKwUvKtoXis9QQ72u+Lfb1tvS6YXrL+wdxPF
# ybOuP2pHqFSxHylk2ChHJT5kXyrWYKsihOy53145GxPHGho5LCb1aI04feJv+vVi
# FgnYIrUxJ/RKTY2qpyUKuRup8QyQ8uonjj46rCh1NW1oGyb7p80w4L6FlmuUeTxV
# azw9SR/QZOtspymP1vRF510suGCii9MVyOcc+VDVEe0a4VKF5t3PbDYC/N9J3PLw
# MYbkgIdeG5ttCcVB4Quvx4TwRnLY9zLHWMOblYyYf11OgbifqKYux8jt+6Opn8I1
# 8ECQr+LtjmujjY1kWrFaUsWHyYzzfBFgjNbgzqovzFqpuXM2pi1zdl5deg==
# SIG # End signature block
