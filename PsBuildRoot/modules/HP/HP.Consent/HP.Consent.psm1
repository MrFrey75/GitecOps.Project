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


enum TelemetryManagedBy
{
  User = 0
  Organization = 1
}

enum TelemetryPurpose
{
  Marketing = 1
  Support = 2
  ProductEnhancement = 3

}


$ConsentPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\HP\Consent'


<#
.SYNOPSIS
  Retrieves the current configured HP Analytics reporting configuration

.DESCRIPTION
    This command retrieves the configuration of the HP Analytics client. The returned object contains the following fields:
    
    - ManagedBy: 'User' (self-managed) or 'Organization' (IT managed)
    - AllowedCollectionPurposes: A collection of allowed purposes, one or more of:
        - Marketing: Analytics are allowed for Marketing purposes
        - Support: Analytics are allowed for Support purposes
        - ProductEnhancement: Analytics are allowed for Product Enhancement purposes
    - TenantID: An organization-configured tenant ID. This is an optional GUID defined by the IT Administrator. If not defined, the TenantID will default to 'Individual'.

.EXAMPLE
    PS C:\> Get-HPAnalyticsConsentConfiguration

    Name                           Value
    ----                           -----
    ManagedBy                      User
    AllowedCollectionPurposes      {Marketing}
    TenantID                       Individual


.LINK
  [Set-HPAnalyticsConsentTenantID](https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentTenantID)

.LINK
    [Set-HPAnalyticsConsentAllowedPurposes](https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentAllowedPurposes)

.LINK
  [Set-HPAnalyticsConsentDeviceOwnership](https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentDeviceOwnership)

.LINK
  For a discussion of these settings, see [https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf](https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf) 

#>
function Get-HPAnalyticsConsentConfiguration
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-HPAnalyticsConsentConfiguration")]
  param()

  $obj = [ordered]@{
    ManagedBy = [TelemetryManagedBy]"User"
    AllowedCollectionPurposes = [TelemetryPurpose[]]@()
    TenantID = "Individual"
  }

  if (Test-Path $ConsentPath)
  {
    $key = Get-ItemProperty $ConsentPath
    if ($key) {
      if ($key.Managed -eq "True") { $obj.ManagedBy = "Organization" }

      [TelemetryPurpose[]]$purpose = @()
      if ($key.AllowMarketing -eq "Accepted") { $purpose += "Marketing" }
      if ($key.AllowSupport -eq "Accepted") { $purpose += "Support" }
      if ($key.AllowProductEnhancement -eq "Accepted") { $purpose += "ProductEnhancement" }

      ([TelemetryPurpose[]]$obj.AllowedCollectionPurposes) = $purpose
      if ($key.TenantID) {
        $obj.TenantID = $key.TenantID
      }

    }


  }
  else {
    Write-Verbose 'Consent registry key does not exist.'
  }
  $obj
}

<#
.SYNOPSIS
    Sets the ManagedBy (ownership) of a device for the purpose of HP Analytics reporting
 
.DESCRIPTION
    This command configures HP Analytics ownership value to either 'User' or 'Organization'.

    - User: This device is managed by the end user
    - Organization: This device is managed by an organization's IT administrator

.PARAMETER Owner
  Specifies User or Organization as the owner of the device

.EXAMPLE
    # Sets the device to be owned by a User
    PS C:\> Set-HPAnalyticsConsentDeviceOwnership -Owner User

.EXAMPLE
    # Sets the device to be owned by an Organization
    PS C:\> Set-HPAnalyticsConsentDeviceOwnership -Owner Organization


.LINK
  [Get-HPAnalyticsConsentConfiguration](https://developers.hp.com/hp-client-management/doc/Get-HPAnalyticsConsentConfiguration)

.LINK
  [Set-HPAnalyticsConsentTenantID](https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentTenantID)

.LINK
    [Set-HPAnalyticsConsentAllowedPurposes](https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentAllowedPurposes)


.LINK
  For a discussion of these settings, see [https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf](https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf) 

.NOTES
  This command requires elevated privileges.

#>
function Set-HPAnalyticsConsentDeviceOwnership
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentDeviceOwnership")]
  param(
    [Parameter(Mandatory = $true,Position = 0)]
    [TelemetryManagedBy]$Owner
  )

  $Managed = ($Owner -eq "Organization")
  New-ItemProperty -Path $ConsentPath -Name "Managed" -Value $Managed -Force | Out-Null

}


<#
.SYNOPSIS
  Sets the Tenant ID of a device for the purpose of HP Analytics reporting

.DESCRIPTION
  This command configures HP Analytics Tenant ID. The Tenant ID is optional and defined by the organization.

  If the Tenant ID is not set, the default value is 'Individual'.

.PARAMETER UUID
  Sets the UUID to the specified GUID. If the TenantID is already configured, the operation will fail unless the -Force parameter is also specified.

.PARAMETER NewUUID
  Sets the UUID to an auto-generated UUID. If the TenantID is already configured, the operation will fail unless the -Force parameter is also specified.

.PARAMETER None
  If specified, this command will remove the TenantID if TenantID is set. TenantID will be set to 'Individual'.

.PARAMETER Force
  If specified, this command will force the Tenant ID to be set even if the Tenant ID is already set. 

.EXAMPLE
  # Sets the tenant ID to a specific UUID
  PS C:\> Set-HPAnalyticsConsentTenantID -UUID 'd34da70b-9d64-47e3-8b3f-9c561df32b98'

.EXAMPLE
  # Sets the tenant ID to an auto-generated UUID
  PS C:\> Set-HPAnalyticsConsentTenantID -NewUUID

.EXAMPLE
  # Removes a configured UUID
  PS C:\> Set-HPAnalyticsConsentTenantID -None

.EXAMPLE
  # Sets (and overwrites) an existing UUID with a new one
  PS C:\> Set-HPAnalyticsConsentTenantID -NewUUID -Force

.LINK
  [Get-HPAnalyticsConsentConfiguration](https://developers.hp.com/hp-client-management/doc/Get-HPAnalyticsConsentConfiguration)

.LINK
  [Set-HPAnalyticsConsentAllowedPurposes](https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentAllowedPurposes)

.LINK
  [Set-HPAnalyticsConsentDeviceOwnership](https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentDeviceOwnership)

.LINK
  For a discussion of these settings, see [https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf](https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf) 

.NOTES
  This command requires elevated privileges.

#>
function Set-HPAnalyticsConsentTenantID
{
  [CmdletBinding(DefaultParameterSetName = "SpecificUUID",HelpUri = "https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentTenantID")]
  param(
    [Parameter(ParameterSetName = 'SpecificUUID',Mandatory = $true,Position = 0)]
    [guid]$UUID,
    [Parameter(ParameterSetName = 'NewUUID',Mandatory = $true,Position = 0)]
    [switch]$NewUUID,
    [Parameter(ParameterSetName = 'None',Mandatory = $true,Position = 0)]
    [switch]$None,
    [Parameter(ParameterSetName = 'SpecificUUID',Mandatory = $false,Position = 1)]
    [Parameter(ParameterSetName = 'NewUUID',Mandatory = $false,Position = 1)]
    [switch]$Force
  )

  if ($NewUUID.IsPresent)
  {
    $uid = [guid]::NewGuid()
  }
  elseif ($None.IsPresent) {
    $uid = "Individual"
  }
  else {
    $uid = $UUID
  }

  if ((-not $Force.IsPresent) -and (-not $None.IsPresent))
  {

    $config = Get-HPAnalyticsConsentConfiguration -Verbose:$VerbosePreference
    if ($config.TenantID -and $config.TenantID -ne "Individual" -and $config.TenantID -ne $uid)
    {

      Write-Verbose "Tenant ID $($config.TenantID) is already configured"
      throw [ArgumentException]"A Tenant ID is already configured for this device. Use -Force to overwrite it."
    }
  }
  New-ItemProperty -Path $ConsentPath -Name "TenantID" -Value $uid -Force | Out-Null
}



<#
.SYNOPSIS
  Sets the allowed reporting purposes for HP Analytics
 
.DESCRIPTION
    This command configures how HP may use the data reported. The allowed purposes are: 

    - Marketing: The data may be used for marketing purposes.
    - Support: The data may be used for support purposes.
    - ProductEnhancement: The data may be used for product enhancement purposes.

    Note that you may supply any combination of the above purpose in a single command. Any of the purposes not included
    in the list will be explicitly rejected.


.PARAMETER AllowedPurposes
    Specifies a list of allowed purposes for the reported data. The value must be one (or more) of the following values: 
    - Marketing
    - Support
    - ProductEnhancement

    The purposes included in this list will be explicitly accepted. The purposes not included in this list will be explicitly rejected.

.PARAMETER None
    If specified, this command rejects all purposes. 


.EXAMPLE
    # Accepts all purposes
    PS C:\> Set-HPAnalyticsConsentAllowedPurposes  -AllowedPurposes Marketing,Support,ProductEnhancement

.EXAMPLE
    # Sets ProductEnhancement, rejects everything else
    PS C:\> Set-HPAnalyticsConsentAllowedPurposes  -AllowedPurposes ProductEnhancement

.EXAMPLE
    # Rejects all purposes
    PS C:\> Set-HPAnalyticsConsentAllowedPurposes  -None
    

.LINK
  [Get-HPAnalyticsConsentConfiguration](https://developers.hp.com/hp-client-management/doc/Get-HPAnalyticsConsentConfiguration)

.LINK
  [Set-HPAnalyticsConsentTenantID](https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentTenantID)

.LINK
  [Set-HPAnalyticsConsentDeviceOwnership](https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentDeviceOwnership)

.LINK
  For a discussion of these settings, see [https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf](https://ftp.hp.com/pub/caps-softpaq/cmit/whitepapers/ManagingConsentforHPAnalytics.pdf) 

.NOTES
  This command requires elevated privileges.

#>
function Set-HPAnalyticsConsentAllowedPurposes
{
  [CmdletBinding(DefaultParameterSetName = "SpecificPurposes",HelpUri = "https://developers.hp.com/hp-client-management/doc/Set-HPAnalyticsConsentAllowedPurposes")]
  param(
    [Parameter(ParameterSetName = 'SpecificPurposes',Mandatory = $true,Position = 0)]
    [TelemetryPurpose[]]$AllowedPurposes,
    [Parameter(ParameterSetName = 'NoPurpose',Mandatory = $true,Position = 0)]
    [switch]$None
  )

  if ($None.IsPresent)
  {
    Write-Verbose "Clearing all opt-in telemetry purposes"
    New-ItemProperty -Path $ConsentPath -Name "AllowMarketing" -Value "Rejected" -Force | Out-Null
    New-ItemProperty -Path $ConsentPath -Name "AllowSupport" -Value "Rejected" -Force | Out-Null
    New-ItemProperty -Path $ConsentPath -Name "AllowProductEnhancement" -Value "Rejected" -Force | Out-Null

  }
  else {
    $allowed = $AllowedPurposes | ForEach-Object {
      New-ItemProperty -Path $ConsentPath -Name "Allow$_" -Value 'Accepted' -Force | Out-Null
      $_
    }

    if ($allowed -notcontains 'Marketing') {
      New-ItemProperty -Path $ConsentPath -Name "AllowMarketing" -Value "Rejected" -Force | Out-Null
    }
    if ($allowed -notcontains 'Support') {
      New-ItemProperty -Path $ConsentPath -Name "AllowSupport" -Value "Rejected" -Force | Out-Null
    }
    if ($allowed -notcontains 'ProductEnhancement') {
      New-ItemProperty -Path $ConsentPath -Name "AllowProductEnhancement" -Value "Rejected" -Force | Out-Null
    }

  }

}


# SIG # Begin signature block
# MIIoGAYJKoZIhvcNAQcCoIIoCTCCKAUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB5sdqcFe4mm2Rh
# 53zIlzvYQzvUCFOQ/vOtBME7gYB7HqCCDYowggawMIIEmKADAgECAhAIrUCyYNKc
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINKmLU5v
# Kd4q4XsFdoIaJmC+Zd+FjKy+yDjptzginaFhMA0GCSqGSIb3DQEBAQUABIIBgFZX
# Po9UnP3sO1GWT3Ztarf0o6paAU0uRDkEUOclfHNSg7lLJdJ7W5GAYR7k46lXDzgl
# IEPxrMbhhp+Uaw1T6ERT2azOsbzIaIRZ7PoR+zhVFWHSjfUSk0YgDyD0JHGPMRkJ
# KuwnU4wuipxGdUxF90z8+b1gxH09OBtDMsv/svCD8GnecTLIzWwddmZ1LbQI6xyx
# HctpJMnqCVmEpr/ZP0Bn0P/A0pASCbc6w6cX/drstSGuKHTGZ/8wfERziPDHW+Jx
# httSZ45BLGZY/G2j5pJQOepxzhbHNjthap9B9pL00S5LKyYcjQJ1tRrCmpZzwlP7
# Ly0iyIcfQu4ghNPXbBtP1ESI9/xVN3YxXGM5QuVJYPrbAFBN3uMty3oOY38fQwl7
# SzFXLp2dHJBf4BBttKP2H8+AhlXeCdPjfWBvxusXFymTmdzXp1DXt8maH4aK1bWT
# cacbKQR1rKuFV0fJm0smuKIcGU23sR51NKTxYl1kf2VgSVQ1RO+cvSa3gIHUS6GC
# Fzowghc2BgorBgEEAYI3AwMBMYIXJjCCFyIGCSqGSIb3DQEHAqCCFxMwghcPAgED
# MQ8wDQYJYIZIAWUDBAIBBQAweAYLKoZIhvcNAQkQAQSgaQRnMGUCAQEGCWCGSAGG
# /WwHATAxMA0GCWCGSAFlAwQCAQUABCCeiiu191Jf6M2Et5B1BtuRoE3r+UZnnjww
# rjVGdqnAIwIRALI1CeH7nBRy7DPStmI360gYDzIwMjUwNDE3MTg0ODU3WqCCEwMw
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
# CRABBDAcBgkqhkiG9w0BCQUxDxcNMjUwNDE3MTg0ODU3WjArBgsqhkiG9w0BCRAC
# DDEcMBowGDAWBBTb04XuYtvSPnvk9nFIUIck1YZbRTAvBgkqhkiG9w0BCQQxIgQg
# PRor6Iy9TwBjobZPtzyEkUvi4WcaSkW9GfN/q1AKh/0wNwYLKoZIhvcNAQkQAi8x
# KDAmMCQwIgQgdnafqPJjLx9DCzojMK7WVnX+13PbBdZluQWTmEOPmtswDQYJKoZI
# hvcNAQEBBQAEggIAtBJXgzYmwsckkMKpuhptDBgTPTTcV1Zkg1Lj7O+63yfNt41+
# BTuurukqPj+NHIPZX0lx/Po/cmNgwzYeuqtJsr92thFDR+MYwZLrfrhXqDO5rKq6
# s1rj7I/0Yq8nf9fx5mAigHmeNIFe3sPZG+MqQcelZ87Yce9zr+JSoQTk/r4uvN5b
# FvcanbN0dwMiez0iNkLD/QRu5Wp8mXc+CheOmBgCvrqQ6gtOO29ELkMA/tBcM4hb
# 8uhs3+hT4o061xeVC7aS+wzYjD30aJIPjos2Ke642KY5wdRuUbSzNpyGY0ssVBLh
# ClRZSEDlHWwDP72E7s+6cvK+7IEi7PVgoxUnLZ4UJ+I6iPd9ui5qGGMsZNRnlY4g
# WUmQWJnjivl3I6IfbxYwEl84Zm3p0PF6wDG+qtgtGlRBigWg8nNw/NUAidt87Tih
# M1kBjTNpQeBDR1suHuJIkOT3OaKbStGALe+1//WIG+wiNUnKAJR7rK/cPwwiXdK6
# MfT8yU3c9Kfl0/wzpvgHsbT1LPcU3nYblBJID+OuSuXFEzGnvooXUkUOuHw0VEZz
# z1DHWG9dmYJKR0evGO+eSIKXUnwdPwBY3v05SgvDFsdFXwzsSVual75g7/t/TfrO
# /u46h2EFOiBfpN0oFRNFu7slRpGsSfJYsgdvzOk5rszS59b0TxbHp1V9poU=
# SIG # End signature block
