#
#  Copyright 2018-2025 HP Development Company, L.P.
#  All Rights Reserved.
#
# NOTICE:  All information contained herein is, and remains the property of HP Inc.
#
# The intellectual and technical concepts contained herein are proprietary to HP Inc
# and may be covered by U.S. and Foreign Patents, patents in process, and are protected by
# trade secret or copyright law. Dissemination of this information or reproduction of this material
# is strictly forbidden unless prior written permission is obtained from HP Inc.

using namespace HP.CMSLHelper

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"
#requires -Modules "HP.Private"

# CMSL is normally installed in C:\Program Files\WindowsPowerShell\Modules
# but if installed via PSGallery and via PS7, it is installed in a different location
if (Test-Path "$PSScriptRoot\..\HP.Private\HP.CMSLHelper.dll") {
  Add-Type -Path "$PSScriptRoot\..\HP.Private\HP.CMSLHelper.dll"
}
else{
  Add-Type -Path "$PSScriptRoot\..\..\HP.Private\1.8.2\HP.CMSLHelper.dll"
}

<#
.SYNOPSIS
  Retrieves the HP Secure Platform Management state

.DESCRIPTION
  This command retrieves the state of the HP Secure Platform Management.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with Secure Platform Management support.
  - This command requires elevated privileges.

.EXAMPLE
  Get-HPSecurePlatformState
#>
function Get-HPSecurePlatformState {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-HPSecurePlatformState")]
  param()
  $mi_result = 0
  $data = New-Object -TypeName provisioning_data_t
 
  if((Test-OSBitness) -eq 32){
    $result = [DfmNativeSecurePlatform]::get_secureplatform_provisioning32([ref]$data,[ref]$mi_result);
  }
  else {
    $result = [DfmNativeSecurePlatform]::get_secureplatform_provisioning64([ref]$data,[ref]$mi_result);
  }

  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x04

  $kek_mod = $data.kek_mod
  [array]::Reverse($kek_mod)

  $sk_mod = $data.sk_mod
  [array]::Reverse($sk_mod)

  # calculating EndorsementKeyID
  $kek_encoded = [System.Convert]::ToBase64String($kek_mod)
  # $kek_decoded = [Convert]::FromBase64String($kek_encoded)
  # $kek_hash = Get-HPPrivateHash -Data $kek_decoded
  # $kek_Id = [System.Convert]::ToBase64String($kek_hash)

  # calculating SigningKeyID
  $sk_encoded = [System.Convert]::ToBase64String($sk_mod)
  # $sk_decoded = [Convert]::FromBase64String($sk_encoded)
  # $sk_hash = Get-HPPrivateHash -Data $sk_decoded
  # $sk_Id = [System.Convert]::ToBase64String($sk_hash)

  # get Sure Admin Mode and Local Access values
  $sure_admin_mode = ""
  $local_access = ""
  if ((Get-HPPrivateIsSureAdminSupported) -eq $true) {
    $sure_admin_state = Get-HPSureAdminState
    $sure_admin_mode = $sure_admin_state.SureAdminMode
    $local_access = $sure_admin_state.LocalAccess
  }

  # calculate FeaturesInUse
  $featuresInUse = ""
  if ($data.features_in_use -eq "SureAdmin") {
    $featuresInUse = "SureAdmin ($sure_admin_mode, Local Access - $local_access)"
  }
  else {
    $featuresInUse = $data.features_in_use
  }

  $obj = [ordered]@{
    State = $data.State
    Version = "$($data.subsystem_version[0]).$($data.subsystem_version[1])"
    Nonce = $($data.arp_counter)
    FeaturesInUse = $featuresInUse
    EndorsementKeyMod = $kek_mod
    SigningKeyMod = $sk_mod
    EndorsementKeyID = $kek_encoded
    SigningKeyID = $sk_encoded
  }
  return New-Object -TypeName PSCustomObject -Property $obj
}


<#
.SYNOPSIS
  Creates an HP Secure Platform Management payload to provision a _Key Endorsement_ key

.DESCRIPTION
  This command creates an HP Secure Platform Management payload to provision a _Key Endorsement_ key. The purpose of the endorsement key is to protect the signing key against unauthorized changes.
  Only holders of the key endorsement private key may change the signing key.

  There are three endorsement options to choose from:
  - Endorsement Key File (and Password) using -EndorsementKeyFile and -EndorsementKeyPassword parameters 
  - Endorsement Key Certificate using -EndorsementKeyCertificate parameter
  - Remote Endorsement using -RemoteEndorsementKeyID and -RemoteSigningServiceURL parameters 

  Please note that using a Key File with Password in PFX format is recommended over using an X509 Certificate object because a private key in a certificate is not password protected.

  This command writes the created payload to the pipeline or to the file specified in the OutputFile parameter.
  This payload can then be passed to the Set-HPSecurePlatformPayload command.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload command. Creating the payload and passing it to the Set-HPSecurePlatformPayload command via the pipeline is not a recommended production pattern.

.PARAMETER EndorsementKeyFile
  Specifies the _Key Endorsement_ key certificate as a PFX (PKCS #12) file

.PARAMETER EndorsementKeyPassword
  Specifies the password for the _Endorsement Key_ PFX file. If no password was used when the PFX was created (not recommended), this parameter may be omitted.

.PARAMETER EndorsementKeyCertificate
  Specifies the endorsement key certificate as an X509Certificate object

.PARAMETER BIOSPassword
  Specifies the BIOS setup password, if any. Note that the password will be in the clear in the generated payload.

.PARAMETER OutputFile
  Specifies the file to write output to instead of writing the output to the pipeline

.PARAMETER RemoteEndorsementKeyID
  Specifies the Endorsement Key ID to be used

.PARAMETER RemoteSigningServiceURL
  Specifies the Key Management Services (KMS) server URL (I.e.: https://<KMSAppName>.azurewebsites.net/). This URL must be HTTPS. 

.PARAMETER CacheAccessToken
  If specified, the access token is cached in msalcache.dat file and user credentials will not be asked again until the credentials expire.
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server. 
  If access token is not cached, the user must re-enter credentials on each call of this command.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.NOTES
  The Key Endorsement private key must never leave a secure server. The payload must be created on a secure server, then may be transferred to a client.

  - Requires HP BIOS with Secure Platform Management support.

.EXAMPLE
   $payload = New-HPSecurePlatformEndorsementKeyProvisioningPayload -EndorsementKeyFile "$path\endorsement_key.pfx"
   ...
   $payload | Set-HPSecurePlatformPayload

#>
function New-HPSecurePlatformEndorsementKeyProvisioningPayload {
  [CmdletBinding(DefaultParameterSetName = "EK_FromFile",HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPSecurePlatformEndorsementKeyProvisioningPayload")]
  param(
    [Parameter(ParameterSetName = "EK_FromFile",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$EndorsementKeyFile,

    [Parameter(ParameterSetName = "EK_FromFile",Mandatory = $false,Position = 1)]
    [string]$EndorsementKeyPassword,

    [Parameter(ParameterSetName = "EK_FromBytes",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$EndorsementKeyCertificate,

    [Parameter(ParameterSetName = "EK_FromFile",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "EK_FromBytes",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 0)]
    [string]$BIOSPassword,

    [Parameter(ParameterSetName = "EK_FromFile",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "EK_FromBytes",Mandatory = $false,Position = 3)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 1)]
    [string]$RemoteEndorsementKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 2)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [switch]$CacheAccessToken
  )

  # only allow https or file paths with or without file:// URL prefix
  if ($RemoteSigningServiceURL -and -not ($RemoteSigningServiceURL.StartsWith("https://",$true,$null) -or [System.IO.Directory]::Exists($RemoteSigningServiceURL) -or $RemoteSigningServiceURL.StartsWith("file://",$true,$null))) {
    throw [System.ArgumentException]"Only HTTPS or valid existing directory paths are supported."
  }

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    if (-not $RemoteSigningServiceURL.EndsWith('/')) {
      $RemoteSigningServiceURL += '/'
    }
    $RemoteSigningServiceURL += 'api/commands/p21ekpubliccert'
    $jsonPayload = New-HPPrivateRemoteSecurePlatformProvisioningJson -EndorsementKeyID $RemoteEndorsementKeyID
    $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
    $response,$responseContent = Send-HPPrivateKMSRequest -KMSUri $RemoteSigningServiceURL -JsonPayload $jsonPayload -AccessToken $accessToken -Verbose:$VerbosePreference
  
    if ($response -eq "OK") {
      $crt = [Convert]::FromBase64String($responseContent)
    }
    else {
      Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
    }
  }
  else {
    $crt = (Get-HPPrivateX509CertCoalesce -File $EndorsementKeyFile -cert $EndorsementKeyCertificate -password $EndorsementKeyPassword -Verbose:$VerbosePreference).Certificate
  }

  Write-Verbose "Creating EK provisioning payload"
  if ($BIOSPassword) {
    $passwordLength = $BIOSPassword.Length
  }
  else {
    $passwordLength = 0
  }

  $opaque = New-Object opaque4096_t
  $opaqueLength = 4096
  $mi_result = 0  

  if((Test-OSBitness) -eq 32){
    $result = [DfmNativeSecurePlatform]::get_ek_provisioning_data32($crt,$($crt.Count),$BIOSPassword, $passwordLength, [ref]$opaque, [ref]$opaqueLength,  [ref]$mi_result);
  }
  else {
    $result = [DfmNativeSecurePlatform]::get_ek_provisioning_data64($crt,$($crt.Count),$BIOSPassword, $passwordLength, [ref]$opaque, [ref]$opaqueLength,  [ref]$mi_result);
  }

  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x04

  $output = New-Object -TypeName PortableFileFormat
  $output.Data = $opaque.raw[0..($opaqueLength - 1)]
  $output.purpose = "hp:provision:endorsementkey"
  $output.timestamp = Get-Date

  if ($OutputFile) {
    Write-Verbose "Will output to file $OutputFile"
    $f = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    $output | ConvertTo-Json -Compress | Out-File $f -Encoding utf8
  }
  else {
    $output | ConvertTo-Json -Compress
  }
}


<#
.SYNOPSIS
  Creates an HP Secure Platform Management payload to provision a _Signing Key_ key

.DESCRIPTION
  This command creates an HP Secure Platform Management payload to provision a _Signing Key_ key. The purpose of the signing key is to sign commands for the Secure Platform Management. The Signing key is protected by the endorsement key. As a result, the endorsement key private key must be available when provisioning or changing the signing key.
  There are three signing options to choose from:
  - Signing Key File (and Password) using -SigningKeyFile and -SigningKeyPassword parameters 
  - Signing Key Certificate using -SigningKeyCertificate parameter
  - Remote Signing using -RemoteSigningServiceKeyID and -RemoteSigningServiceURL parameters 

  There are three endorsement options to choose from:
  - Endorsement Key File (and Password) using -EndorsementKeyFile and -EndorsementKeyPassword parameters 
  - Endorsement Key Certificate using -EndorsementKeyCertificate parameter
  - Remote Endorsement using -RemoteEndorsementKeyID and -RemoteSigningServiceURL parameters 

  Please note that using a Key File with Password in PFX format is recommended over using an X509 Certificate object because a private key in a certificate is not password protected.

  This command writes the created payload to the pipeline or to the file specified in the -OutputFile parameter. This payload can then be passed to the Set-HPSecurePlatformPayload command.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload command. Please note that creating the payload and passing it to the Set-HPSecurePlatformPayload command via the pipeline is not a recommended production pattern.

.PARAMETER EndorsementKeyFile
  Specifies the _Key Endorsement_ key certificate as a PFX (PKCS #12) file

.PARAMETER EndorsementKeyPassword
  Specifies the password for the _Endorsement Key_ PFX file. If no password was used when the PFX was created (which is not recommended), this parameter may be omitted.

.PARAMETER EndorsementKeyCertificate
  Specifies the endorsement key certificate as an X509Certificate object

.PARAMETER SigningKeyFile
  Specifies the path to the Secure Platform Management signing key as a PFX file. If the PFX file is protected by a password (recommended), the SigningKeyPassword parameter should also be provided.

.PARAMETER SigningKeyCertificate
  Specifies the Secure Platform Management signing key certificate as an X509Certificate object

.PARAMETER SigningKeyPassword
  Specifies the Secure Platform Management signing key file password, if required.

.PARAMETER Nonce
  Specifies a Nonce. If nonce is specified, the Secure Platform Management subsystem will only accept commands with a nonce greater or equal to the last nonce sent. This approach helps to prevent replay attacks. If not specified, the nonce is inferred from the current local time. The current local time as the nonce works in most cases. However, this approach has a resolution of seconds, so when performing parallel operations or a high volume of operations, it is possible for the same counter to be interpreted for more than one command. In these cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER OutputFile
  Specifies the file to write output to instead of writing the output to the pipeline

.PARAMETER RemoteEndorsementKeyID
  Specifies the Endorsement Key ID to be used

.PARAMETER RemoteSigningKeyID
  Specifies the Signing Key ID to be provisioned

.PARAMETER RemoteSigningServiceURL
  Specifies the (Key Management Service) KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/). This URL must be HTTPS. 

.PARAMETER CacheAccessToken
  If specified, the access token is cached in msalcache.dat file and user credentials will not be asked again until the credentials expire.
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server. 
  If access token is not cached, the user must re-enter credentials on each call of this command.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with Secure Platform Management support.

.EXAMPLE
  $payload = New-HPSecurePlatformSigningKeyProvisioningPayload -EndorsementKeyFile "$path\endorsement_key.pfx"  `
               -SigningKeyFile "$path\signing_key.pfx"
  ...
  $payload | Set-HPSecurePlatformPayload

#>
function New-HPSecurePlatformSigningKeyProvisioningPayload {
  [CmdletBinding(DefaultParameterSetName = "EF_SF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPSecurePlatformSigningKeyProvisioningPayload")]
  param(
    [Parameter(ParameterSetName = "EF_SF",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "EF_SB",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$EndorsementKeyFile,

    [Parameter(ParameterSetName = "EF_SF",Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = "EF_SB",Mandatory = $false,Position = 1)]
    [string]$EndorsementKeyPassword,

    [Parameter(ParameterSetName = "EF_SF",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "EB_SF",Mandatory = $false,Position = 2)]
    [System.IO.FileInfo]$SigningKeyFile,

    [Parameter(ParameterSetName = "EF_SF",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "EB_SF",Mandatory = $false,Position = 3)]
    [string]$SigningKeyPassword,

    [Parameter(ParameterSetName = "EB_SF",Mandatory = $true,Position = 0)]
    [Parameter(ParameterSetName = "EB_SB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$EndorsementKeyCertificate,

    [Parameter(ValueFromPipeline = $true,ParameterSetName = "EB_SB",Mandatory = $false,Position = 2)]
    [Parameter(ValueFromPipeline = $true,ParameterSetName = "EF_SB",Mandatory = $false,Position = 2)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$SigningKeyCertificate,

    [Parameter(ParameterSetName = "EF_SF",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "EB_SF",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "EF_SB",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "EB_SB",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "EF_SF",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "EB_SF",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "EF_SB",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "EB_SB",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [string]$RemoteEndorsementKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 4)]
    [string]$RemoteSigningKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 5)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 6)]
    [switch]$CacheAccessToken
  )

  # only allow https or file paths with or without file:// URL prefix
  if ($RemoteSigningServiceURL -and -not ($RemoteSigningServiceURL.StartsWith("https://",$true,$null) -or [System.IO.Directory]::Exists($RemoteSigningServiceURL) -or $RemoteSigningServiceURL.StartsWith("file://",$true,$null))) {
    throw [System.ArgumentException]"Only HTTPS or valid existing directory paths are supported."
  }

  if ($PSCmdlet.ParameterSetName -eq "RemoteSigning") {
    if (-not $RemoteSigningServiceURL.EndsWith('/')) {
      $RemoteSigningServiceURL += '/'
    }
    $RemoteSigningServiceURL += 'api/commands/p21skprovisioningpayload'

    $params = @{
      EndorsementKeyID = $RemoteEndorsementKeyID
      Nonce = $Nonce
    }
    if ($RemoteSigningKeyID) {
      $params.SigningKeyID = $RemoteSigningKeyID
    }

    $jsonPayload = New-HPPrivateRemoteSecurePlatformProvisioningJson @params
    $accessToken = Get-HPPrivateSureAdminKMSAccessToken -CacheAccessToken:$CacheAccessToken
    $response,$responseContent = Send-HPPrivateKMSRequest -KMSUri $RemoteSigningServiceURL -JsonPayload $jsonPayload -AccessToken $accessToken -Verbose:$VerbosePreference
  
    if ($response -eq "OK") {
      return $responseContent
    }
    else {
      Invoke-HPPrivateKMSErrorHandle -ApiResponseContent $responseContent -Status $response
    }
  }
  else {
    $ek = Get-HPPrivateX509CertCoalesce -File $EndorsementKeyFile -password $EndorsementKeyPassword -cert $EndorsementKeyCertificate -Verbose:$VerbosePreference
    $sk = $null
    if ($SigningKeyFile -or $SigningKeyCertificate) {
      $sk = Get-HPPrivateX509CertCoalesce -File $SigningKeyFile -password $SigningKeyPassword -cert $SigningKeyCertificate -Verbose:$VerbosePreference
    }

    Write-Verbose "Creating SK provisioning payload"

    $payload = New-Object sk_provisioning_t
    $sub = New-Object sk_provisioning_payload_t

    $sub.Counter = $nonce
    if ($sk) {
      $sub.mod = $Sk.Modulus
    }
    else {
      Write-Verbose "Assuming deprovisioning due to missing signing key update"
      $sub.mod = New-Object byte[] 256
    }
    $payload.Data = $sub
    Write-Verbose "Using counter value of $($sub.Counter)"
    $out = Convert-HPPrivateObjectToBytes -obj $sub -Verbose:$VerbosePreference
    $payload.sig = Invoke-HPPrivateSignData -Data $out[0] -Certificate $ek.Full -Verbose:$VerbosePreference


    Write-Verbose "Serializing payload"
    $out = Convert-HPPrivateObjectToBytes -obj $payload -Verbose:$VerbosePreference

    $output = New-Object -TypeName PortableFileFormat
    $output.Data = ($out[0])[0..($out[1] - 1)];
    $output.purpose = "hp:provision:signingkey"
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
}

function New-HPPrivateRemoteSecurePlatformProvisioningJson {
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [uint32]$Nonce,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 2)]
    [string]$EndorsementKeyId,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 3)]
    [string]$SigningKeyId
  )

  $payload = [ordered]@{
    EKId = $EndorsementKeyId
  }

  if ($Nonce) {
    $payload['Nonce'] = $Nonce
  }

  if ($SigningKeyId) {
    $payload['SKId'] = $SigningKeyId
  }

  $payload | ConvertTo-Json -Compress
}

<#
.SYNOPSIS
  Creates a deprovisioning payload

.DESCRIPTION
  This command creates a payload to deprovision the HP Secure Platform Management. The caller must have access to the Endorsement Key private key in order to create this payload.

  There are three endorsement options to choose from:
  - Endorsement Key File (and Password) using -EndorsementKeyFile and -EndorsementKeyPassword parameters 
  - Endorsement Key Certificate using -EndorsementKeyCertificate parameter
  - Remote Endorsement using -RemoteEndorsementKeyID and -RemoteSigningServiceURL parameters 
  
  Please note that using a Key File with Password in PFX format is recommended over using an X509 Certificate object because a private key in a certificate is not password protected.

  This command writes the created payload to the pipeline or to the file specified in the -OutputFile parameter. This payload can then be passed to the Set-HPSecurePlatformPayload command.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload command. Creating the payload and passing it to the Set-HPSecurePlatformPayload command via the pipeline is not a recommended production pattern.

.PARAMETER EndorsementKeyFile
  Specifies the _Key Endorsement_ key certificate as a PFX (PKCS #12) file

.PARAMETER EndorsementKeyPassword
  The password for the endorsement key certificate file. If no password was used when the PFX was created (which is not recommended), this parameter may be omitted.

.PARAMETER EndorsementKeyCertificate
  Specifies the endorsement key certificate as an X509Certificate object

.PARAMETER Nonce
  Specifies a Nonce. If nonce is specified, the Secure Platform Management subsystem will only accept commands with a nonce greater or equal to the last nonce sent. This approach helps to prevent replay attacks. If not specified, the nonce is inferred from the current local time. The current local time as the nonce works in most cases. However, this approach has a resolution of seconds, so when performing parallel operations or a high volume of operations, it is possible for the same counter to be interpreted for more than one command. In these cases, the caller should use its own nonce derivation and provide it through this parameter.

.PARAMETER RemoteEndorsementKeyID
  Specifies the Endorsement Key ID to be used

.PARAMETER RemoteSigningServiceURL
  Specifies the (Key Management Service) KMS server URL (I.e.: https://<KMSAppName>.azurewebsites.net/). This URL must be HTTPS. 

.PARAMETER CacheAccessToken
  If specified, the access token is cached in msalcache.dat file and user credentials will not be asked again until the credentials expire.
  This parameter should be specified for caching the access token when performing multiple operations on the KMS server. 
  If access token is not cached, the user must re-enter credentials on each call of this command.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.PARAMETER OutputFile
  Specifies the file to write output to instead of writing the output to the pipeline

.NOTES
  - Requires HP BIOS with Secure Platform Management support.

.EXAMPLE
  New-HPSecurePlatformDeprovisioningPayload -EndorsementKeyFile kek.pfx | Set-HPSecurePlatformPayload

.EXAMPLE
  New-HPSecurePlatformDeprovisioningPayload -EndorsementKeyFile kek.pfx -OutputFile deprovisioning_payload.dat
#>
function New-HPSecurePlatformDeprovisioningPayload {
  [CmdletBinding(DefaultParameterSetName = "EF",HelpUri = "https://developers.hp.com/hp-client-management/doc/New-HPSecurePlatformDeprovisioningPayload")]
  param(
    [Parameter(ParameterSetName = "EF",Mandatory = $true,Position = 0)]
    [string]$EndorsementKeyFile,

    [Parameter(ParameterSetName = "EF",Mandatory = $false,Position = 1)]
    [string]$EndorsementKeyPassword,

    [Parameter(ParameterSetName = "EF",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "EB",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 1)]
    [uint32]$Nonce = [math]::Floor([decimal](Get-Date (Get-Date).ToUniversalTime() -UFormat "%s").Replace(',','.')),

    [Parameter(ParameterSetName = "EB",Mandatory = $true,Position = 0)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$EndorsementKeyCertificate,

    [Parameter(ParameterSetName = "EB",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "EF",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 2)]
    [System.IO.FileInfo]$OutputFile,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 3)]
    [string]$RemoteEndorsementKeyID,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $true,Position = 4)]
    [string]$RemoteSigningServiceURL,

    [Parameter(ParameterSetName = "RemoteSigning",Mandatory = $false,Position = 5)]
    [switch]$CacheAccessToken
  )

  # only allow https or file paths with or without file:// URL prefix
  if ($RemoteSigningServiceURL -and -not ($RemoteSigningServiceURL.StartsWith("https://",$true,$null) -or [System.IO.Directory]::Exists($RemoteSigningServiceURL) -or $RemoteSigningServiceURL.StartsWith("file://",$true,$null))) {
    throw [System.ArgumentException]"Only HTTPS or valid existing directory paths are supported."
  }

  New-HPSecurePlatformSigningKeyProvisioningPayload @PSBoundParameters
}

<#
.SYNOPSIS
  Applies a payload to HP Secure Platform Management

.DESCRIPTION
  This command applies a properly encoded payload created by one of the New-HPSecurePlatform*, New-HPSureRun*, New-HPSureAdmin*, or New-HPSureRecover* commands to the BIOS.
  
  Payloads created by means other than the commands mentioned above are not supported.

  Security note: Payloads should only be created on secure servers. Once created, the payload may be transferred to a client and applied via the Set-HPSecurePlatformPayload command. Creating the payload and passing it to the Set-HPSecurePlatformPayload command via the pipeline is not a recommended production pattern.

.PARAMETER Payload
  Specifies the payload to apply. This parameter can also be specified via the pipeline.

.PARAMETER PayloadFile
  Specifies the payload file to apply. This file must contain a properly encoded payload.

.LINK
  [Blog post: HP Secure Platform Management with the HP Client Management Script Library](https://developers.hp.com/hp-client-management/blog/hp-secure-platform-management-hp-client-management-script-library)

.NOTES
  - Requires HP BIOS with Secure Platform Management support.
  - This command requires elevated privileges.

.EXAMPLE
  Set-HPSecurePlatformPayload -Payload $payload

.EXAMPLE
  Set-HPSecurePlatformPayload -PayloadFile .\payload.dat

.EXAMPLE
  $payload | Set-HPSecurePlatformPayload
#>
function Set-HPSecurePlatformPayload {

  [CmdletBinding(DefaultParameterSetName = "FB",HelpUri = "https://developers.hp.com/hp-client-management/doc/Set-HPSecurePlatformPayload")]
  param(
    [Parameter(ParameterSetName = "FB",ValueFromPipeline = $true,Position = 0,Mandatory = $True)] [string]$Payload,
    [Parameter(ParameterSetName = "FF",ValueFromPipeline = $true,Position = 0,Mandatory = $True)] [System.IO.FileInfo]$PayloadFile
  )

  if ($PSCmdlet.ParameterSetName -eq "FB") {
    Write-Verbose "Setting payload string"
    [PortableFileFormat]$type = ConvertFrom-Json -InputObject $Payload
  }
  else {
    Write-Verbose "Setting from file $PayloadFile"
    $Payload = Get-Content -Path $PayloadFile -Encoding UTF8
    [PortableFileFormat]$type = ConvertFrom-Json -InputObject $Payload
  }

  $mi_result = 0
  $pbytes = $type.Data
  Write-Verbose "Setting payload from document with type $($type.purpose)"

  $result = $null
  switch ($type.purpose) {
    "hp:provision:endorsementkey" {
      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSecurePlatform]::set_ek_provisioning32($pbytes,$pbytes.length, [ref]$mi_result);
      }
      else {
        $result = [DfmNativeSecurePlatform]::set_ek_provisioning64($pbytes,$pbytes.length, [ref]$mi_result);
      }
    }
    "hp:provision:signingkey" {
      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSecurePlatform]::set_sk_provisioning32($pbytes,$pbytes.length, [ref]$mi_result);
      }
      else {
        $result = [DfmNativeSecurePlatform]::set_sk_provisioning64($pbytes,$pbytes.length, [ref]$mi_result);
      }
    }
    "hp:surerecover:provision:os_image" {
      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSureRecover]::set_surerecover_osr_provisioning32($pbytes,$pbytes.length, [ref]$mi_result);
      }
      else {
        $result = [DfmNativeSureRecover]::set_surerecover_osr_provisioning64($pbytes,$pbytes.length, [ref]$mi_result);
      }
    }
    "hp:surerecover:provision:recovery_image" {
      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSureRecover]::set_surerecover_re_provisioning32($pbytes,$pbytes.length, [ref]$mi_result);
      }
      else {
        $result = [DfmNativeSureRecover]::set_surerecover_re_provisioning64($pbytes,$pbytes.length, [ref]$mi_result);
      }
    }
    "hp:surerecover:failover:os_image" {
      if (-not (Get-HPSureRecoverState).ImageIsProvisioned) {
        throw [System.IO.InvalidDataException]"Custom OS Recovery Image is required to configure failover"
      }

      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSureRecover]::set_surerecover_osr_failover32($pbytes,$pbytes.length,[ref]$mi_result);
      }
      else {
        $result = [DfmNativeSureRecover]::set_surerecover_osr_failover64($pbytes,$pbytes.length,[ref]$mi_result);
      }
    }
    "hp:surerecover:deprovision" {
      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSureRecover]::set_surerecover_deprovision_opaque32($pbytes,$pbytes.length, [ref]$mi_result);
      }
      else {
        $result = [DfmNativeSureRecover]::set_surerecover_deprovision_opaque64($pbytes,$pbytes.length, [ref]$mi_result);
      }
    }
    "hp:surerecover:scheduler" {
      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSureRecover]::set_surerecover_schedule32($pbytes,$pbytes.length, [ref]$mi_result);
      }
      else {
        $result = [DfmNativeSureRecover]::set_surerecover_schedule64($pbytes,$pbytes.length, [ref]$mi_result);
      }
    }
    "hp:surerecover:configure" {
      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSureRecover]::set_surerecover_configuration32($pbytes,$pbytes.length, [ref]$mi_result);
      }
      else {
        $result = [DfmNativeSureRecover]::set_surerecover_configuration64($pbytes,$pbytes.length, [ref]$mi_result);
      }
    }
    "hp:surerecover:trigger" {
      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSureRecover]::set_surerecover_trigger32($pbytes,$pbytes.length, [ref]$mi_result);
      }
      else {
        $result = [DfmNativeSureRecover]::set_surerecover_trigger64($pbytes,$pbytes.length, [ref]$mi_result);
      }
    }
    "hp:surerecover:service_event" {
      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSureRecover]::raise_surerecover_service_event_opaque32($null,0, [ref]$mi_result);
      }
      else {
        $result = [DfmNativeSureRecover]::raise_surerecover_service_event_opaque64($null,0, [ref]$mi_result);
      }
    }
    "hp:surerrun:manifest" {
      $mbytes = $type.Meta1
      if((Test-OSBitness) -eq 32){
        $result = [DfmNativeSureRun]::set_surererun_manifest32($pbytes,$pbytes.length, $mbytes, $mbytes.length, [ref]$mi_result);
      }
      else {
        $result = [DfmNativeSureRun]::set_surererun_manifest64($pbytes,$pbytes.length, $mbytes, $mbytes.length, [ref]$mi_result);
      }
    }
    "hp:sureadmin:biossetting" {
      $Payload | Set-HPPrivateBIOSSettingValuePayload -Verbose:$VerbosePreference
    }
    "hp:sureadmin:biossettingslist" {
      $Payload | Set-HPPrivateBIOSSettingsListPayload -Verbose:$VerbosePreference
    }
    "hp:sureadmin:resetsettings" {
      $Payload | Set-HPPrivateBIOSSettingDefaultsPayload -Verbose:$VerbosePreference
    }
    "hp:sureadmin:firmwareupdate" {
      $Payload | Set-HPPrivateFirmwareUpdatePayload -Verbose:$VerbosePreference
    }
    default {
      throw [System.IO.InvalidDataException]"Document type $($type.purpose) not recognized"
    }
  }

  if ($result) {
    Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x04
  }
}

# SIG # Begin signature block
# MIIoGAYJKoZIhvcNAQcCoIIoCTCCKAUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAPGV40cbZpiMVm
# JWI/kFFTqDb1oCTEpXjlojEmT8SybqCCDYowggawMIIEmKADAgECAhAIrUCyYNKc
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
# 8QVJxN0unuKdIbJiYJkldVgMyhT0I95EKSKsuLWK+VKUWu/MMYIZ5DCCGeACAQEw
# fTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNV
# BAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hB
# Mzg0IDIwMjEgQ0ExAhAGbBUteYe7OrU/9UuqLvGSMA0GCWCGSAFlAwQCAQUAoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEqC3kbb
# BJ/rqvCupIlPQEbuceREfnMasjVpm7iWoGOnMA0GCSqGSIb3DQEBAQUABIIBgCP6
# CLuTAhjhPaZPxQWpu9zAvXGEk9+aNeNr+hSbM4XWXnqWBpIlersA1NTSBBkTZy4c
# Jd5N1M8o18He8lCBP2vepTDQnGc4R+VlTk5KbPZcUKkUOPCl2cYZCiMnWm3keACL
# s7iLrkYC+QV9GioTDKy1/CzHQHn9FhBSPwa30siTsCauRF9u/7mGFNe4lHxvZ0km
# dZVGrb3OVkCtmtQiz4D5BYNPWd55lHkyLZCobaYknA376zf47Qlzy91UXxQMxTWz
# NZDRq/GW49/e/ucfghAHAxEX6LLj7VfewIz/YNmtcOs4RNWxBeKHjIzoHfQBDqSo
# +i48WXsHNBgD1D/8DP/BJZGZ8BBfRBli6PQ63aJzlWLWJHV1/zXpdyrsQlxBMkdz
# Dns/od9JBlb3SkfbNL+jHruIfTxXDaKUarbhj/fZ7ECG+TzaQaYTZlOYou/SVjlS
# fAbzLA2R4fjNE+2DZcPHF2Yx0oCdl7ab7DftQoewNMYIzmZ9gXn2WVVZvn/gzKGC
# Fzowghc2BgorBgEEAYI3AwMBMYIXJjCCFyIGCSqGSIb3DQEHAqCCFxMwghcPAgED
# MQ8wDQYJYIZIAWUDBAIBBQAweAYLKoZIhvcNAQkQAQSgaQRnMGUCAQEGCWCGSAGG
# /WwHATAxMA0GCWCGSAFlAwQCAQUABCA4/UiAHkTe24gJd3coO2x/6avumunEXpTH
# oEVk+itT4AIRAPyW1FyENjAlRLlhTRNyEqYYDzIwMjUwNDE3MTg0ODQ3WqCCEwMw
# gga8MIIEpKADAgECAhALrma8Wrp/lYfG+ekE4zMEMA0GCSqGSIb3DQEBCwUAMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwHhcNMjQwOTI2MDAwMDAwWhcNMzUxMTI1MjM1OTU5WjBCMQswCQYDVQQGEwJV
# UzERMA8GA1UEChMIRGlnaUNlcnQxIDAeBgNVBAMTF0RpZ2lDZXJ0IFRpbWVzdGFt
# cCAyMDI0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAvmpzn/aVIauW
# MLpbbeZZo7Xo/ZEfGMSIO2qZ46XB/QowIEMSvgjEdEZ3v4vrrTHleW1JWGErrjOL
# 0J4L0HqVR1czSzvUQ5xF7z4IQmn7dHY7yijvoQ7ujm0u6yXF2v1CrzZopykD07/9
# fpAT4BxpT9vJoJqAsP8YuhRvflJ9YeHjes4fduksTHulntq9WelRWY++TFPxzZrb
# ILRYynyEy7rS1lHQKFpXvo2GePfsMRhNf1F41nyEg5h7iOXv+vjX0K8RhUisfqw3
# TTLHj1uhS66YX2LZPxS4oaf33rp9HlfqSBePejlYeEdU740GKQM7SaVSH3TbBL8R
# 6HwX9QVpGnXPlKdE4fBIn5BBFnV+KwPxRNUNK6lYk2y1WSKour4hJN0SMkoaNV8h
# yyADiX1xuTxKaXN12HgR+8WulU2d6zhzXomJ2PleI9V2yfmfXSPGYanGgxzqI+Sh
# oOGLomMd3mJt92nm7Mheng/TBeSA2z4I78JpwGpTRHiT7yHqBiV2ngUIyCtd0pZ8
# zg3S7bk4QC4RrcnKJ3FbjyPAGogmoiZ33c1HG93Vp6lJ415ERcC7bFQMRbxqrMVA
# Niav1k425zYyFMyLNyE1QulQSgDpW9rtvVcIH7WvG9sqYup9j8z9J1XqbBZPJ5XL
# ln8mS8wWmdDLnBHXgYly/p1DhoQo5fkCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQE
# AwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1Ud
# IAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUv
# cyl2mi91jGogj57IbzAdBgNVHQ4EFgQUn1csA3cOKBWQZqVjXu5Pkh92oFswWgYD
# VR0fBFMwUTBPoE2gS4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYB
# BQUHAQEEgYMwgYAwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBYBggrBgEFBQcwAoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkq
# hkiG9w0BAQsFAAOCAgEAPa0eH3aZW+M4hBJH2UOR9hHbm04IHdEoT8/T3HuBSyZe
# q3jSi5GXeWP7xCKhVireKCnCs+8GZl2uVYFvQe+pPTScVJeCZSsMo1JCoZN2mMew
# /L4tpqVNbSpWO9QGFwfMEy60HofN6V51sMLMXNTLfhVqs+e8haupWiArSozyAmGH
# /6oMQAh078qRh6wvJNU6gnh5OruCP1QUAvVSu4kqVOcJVozZR5RRb/zPd++PGE3q
# F1P3xWvYViUJLsxtvge/mzA75oBfFZSbdakHJe2BVDGIGVNVjOp8sNt70+kEoMF+
# T6tptMUNlehSR7vM+C13v9+9ZOUKzfRUAYSyyEmYtsnpltD/GWX8eM70ls1V6QG/
# ZOB6b6Yum1HvIiulqJ1Elesj5TMHq8CWT/xrW7twipXTJ5/i5pkU5E16RSBAdOp1
# 2aw8IQhhA/vEbFkEiF2abhuFixUDobZaA0VhqAsMHOmaT3XThZDNi5U2zHKhUs5u
# HHdG6BoQau75KiNbh0c+hatSF+02kULkftARjsyEpHKsF7u5zKRbt5oK5YGwFvgc
# 4pEVUNytmB3BpIiowOIIuDgP5M9WArHYSAR16gc0dP2XdkMEP5eBsX7bf/MGN4K3
# HP50v/01ZHo/Z5lGLvNwQ7XHBx1yomzLP8lx4Q1zZKDyHcp4VQJLu2kWTsKsOqQw
# ggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqGSIb3DQEBCwUAMGIx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBH
# NDAeFw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1
# c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwggIiMA0GCSqG
# SIb3DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXHJQPE8pE3qZdRodbS
# g9GeTKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMfUBMLJnOWbfhXqAJ9
# /UO0hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w1lbU5ygt69OxtXXn
# HwZljZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRktFLydkf3YYMZ3V+0
# VAshaG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYbqMFkdECnwHLFuk4f
# sbVYTXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUmcJgmf6AaRyBD40Nj
# gHt1biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP65x9abJTyUpURK1h0
# QCirc0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzKQtwYSH8UNM/STKvv
# mz3+DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo80VgvCONWPfcYd6T
# /jnA+bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjBJgj5FBASA31fI7tk
# 42PgpuE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXcheMBK9Rp6103a50g5r
# mQzSM7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4E
# FgQUuhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5n
# P+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcG
# CCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8v
# Y3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNV
# HSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIB
# AH1ZjsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd4ksp+3CKDaopafxp
# wc8dB+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiCqBa9qVbPFXONASIl
# zpVpP0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl/Yy8ZCaHbJK9nXzQ
# cAp876i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeCRK6ZJxurJB4mwbfe
# Kuv2nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYTgAnEtp/Nh4cku0+j
# Sbl3ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/a6fxZsNBzU+2QJsh
# IUDQtxMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37xJV77QpfMzmHQXh6
# OOmc4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmLNriT1ObyF5lZynDw
# N7+YAN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0YgkPCr2B2RP+v6TR
# 81fZvAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJRyvmfxqkhQ/8mJb2
# VVQrH4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MIIFjTCCBHWgAwIBAgIQ
# DpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAx
# MDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQD
# ExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aa
# za57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllV
# cq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT
# +CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd
# 463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+
# EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92k
# J7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5j
# rubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7
# f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJU
# KSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+wh
# X8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQAB
# o4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5n
# P+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0P
# AQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDww
# OqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IB
# AQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229
# GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FD
# RJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVG
# amlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCw
# rFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvR
# XKwYw02fc7cBqZ9Xql4o4rmUMYIDdjCCA3ICAQEwdzBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhALrma8Wrp/lYfG
# +ekE4zMEMA0GCWCGSAFlAwQCAQUAoIHRMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0B
# CRABBDAcBgkqhkiG9w0BCQUxDxcNMjUwNDE3MTg0ODQ3WjArBgsqhkiG9w0BCRAC
# DDEcMBowGDAWBBTb04XuYtvSPnvk9nFIUIck1YZbRTAvBgkqhkiG9w0BCQQxIgQg
# MicRPl+CIBUaulwv/H8y7apQiYF45JmcPk5r/fAFuEUwNwYLKoZIhvcNAQkQAi8x
# KDAmMCQwIgQgdnafqPJjLx9DCzojMK7WVnX+13PbBdZluQWTmEOPmtswDQYJKoZI
# hvcNAQEBBQAEggIAioVfOblHOOTb2WAGjX60puTm3H+XJpW+eqjymoR17TLucXhh
# /KbVhyBCDv2jpu745o5VquDShOzQkjDVRU6apzmm0T2oeP8l1Wfu22nEc6Nltxfl
# Tx8WXcaavaj5e0TTB3PxDTzpsvGLYKn46r6vNrR1tFaB77NViOE8ailgjGqJ0dij
# 17zJX/t6vKhx/fa8necpKhfWKcAFHaI8SbWypJVNf6BDEY7QT06kuMczabDlmCrP
# w+eCuHYX4vFZ57ZszE8xyzzUZDnD5oZZNhNFWDo37FV+VUD5wjgicMmHniFExu5l
# os3Llnn1OeJmNvkoVFF+MWTb79tuSQL7JOPR+Z9bx5IvED9vRObrel5nYe9SVeil
# 4YFTGSUG05Opuk+997OQ9lKNxlBuYsksKgUC2fMemqZrjDMQUG41roVEsN++jf9T
# QS1vK7zV5Yz3QAZFyWOon5rM+U1SOlkyERgPKGbx8hleC2DDY6yc2oCqQbt75xAC
# yTEoaiWhG2asBSFpr7DzB/7ipUgH0jEVpOcnQdgiUoIERaHLeYMkmue4XKwsxF49
# 7lNCImL3b1f0TLj1/M3rXAedRJiFbscSqqRoalGQNtsZGcucc7V2jFbLO2vF6Jf+
# IssxoAbcyNh8QR0iSHY3F82qSCIm9B0sPDETQdhaxl+mLi7RkjIjs8SHYjE=
# SIG # End signature block
