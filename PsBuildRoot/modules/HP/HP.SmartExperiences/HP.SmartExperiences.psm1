Set-StrictMode -Version 3.0
#requires -Modules "HP.Private","HP.ClientManagement"

<#
.SYNOPSIS
  Sets Smart Experiences as managed or unmanaged 

.DESCRIPTION
  If Smart Experiences\Policy is not found on the registry, this command sets the 'Privacy Alert' and 'Auto Screen Dimming' features to the default values. 

  The default values for both 'Privacy Alert' and 'Auto Screen Dimming' are:
    - AllowEdit: $true
    - Default: Off
    - Enabled: $false
   
  Use the Set-HPeAISettingValue command to configure the values of the eAI features.

.PARAMETER Enabled
  If set to $true, this command will configure eAi as managed. If set to $false, this command will configure eAI as unmanaged. 

.EXAMPLE
  Set-HPeAIManaged -Enabled $true

.NOTES
  Admin privilege is required.

.LINK
  [Get-HPeAISettingValue](https://developers.hp.com/hp-client-management/doc/Get-HPeAISettingValue)

.LINK
  [Set-HPeAISettingValue](https://developers.hp.com/hp-client-management/doc/Set-HPeAISettingValue)
#>
function Set-HPeAIManaged {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Set-HPeAIManaged")]
  param(
    [Parameter(Mandatory = $true,Position = 0,ValueFromPipeline = $true)]
    [bool]$Enabled
  )
  $eAIRegPath = 'HKLM:\Software\Policies\HP\SmartExperiences'

  if ((Test-HPSmartExperiencesIsSupported) -eq $false) {
    throw [System.NotSupportedException]"HP Smart Experiences is currently not supported on this platform."
  }

  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

  $reg = Get-Item -Path $eAIRegPath -ErrorAction SilentlyContinue
  if ($null -eq $reg) {
    Write-Verbose "Creating registry entry $eAIRegPath"
    New-Item -Path $eAIRegPath -Force | Out-Null
  }

  if ($true -eq $Enabled) {
    $managed = 1

    # Check if eAI attributes exist, if not, set the defaults
    Write-Verbose "Reading registry path $eAIRegPath\Policy"
    $reg = Get-ItemProperty -Path $eAIRegPath -ErrorAction SilentlyContinue -Name Policy
    if ($reg) {
      Write-Verbose "$eAIRegPath\Policy attributes found"
      try {
        Write-Verbose "Data read: $($reg.Policy)"
        $current = $reg.Policy | ConvertFrom-Json
      }
      catch {
        throw [System.FormatException]"$($_.Exception.Message): Please ensure Policy property contains a valid JSON."
      }
    }
    else {
      $current = [ordered]@{
        attentionDim = [ordered]@{
          allowEdit = $true
          default = 0
          isEnabled = $false
        }
        shoulderSurf = [ordered]@{
          allowEdit = $true
          default = 0
          isEnabled = $false
        }
      }

      $value = $current | ConvertTo-Json -Compress
      Write-Verbose "Setting $eAIRegPath\Policy to defaults $value"
    
      if ($reg) {
        Set-ItemProperty -Path $eAIRegPath -Value $value -Name Policy -Force | Out-Null
      }
      else {
        New-ItemProperty -Path $eAIRegPath -Value $value -Name Policy -Force | Out-Null
      }
    }
  }
  else {
    $managed = 0
  }

  Write-Verbose "Setting $eAIRegPath\Managed to $managed"
  $reg = Get-ItemProperty -Path $eAIRegPath -ErrorAction SilentlyContinue -Name Managed
  if ($reg) {
    Set-ItemProperty -Path $eAIRegPath -Value $managed -Name Managed -Force | Out-Null
  }
  else {
    New-ItemProperty -Path $eAIRegPath -Value $managed -Name Managed -Force | Out-Null
  }
}

<#
.SYNOPSIS
  Checks if eAI is managed on the current device
.DESCRIPTION
  If eAI is managed, this command returns true. Otherwise, this command returns false. If 'SmartExperiences' entry is not found in the registry, false is returned by default.

.EXAMPLE
  Get-HPeAIManaged

.NOTES
  Admin privilege is required.

.LINK
  [Set-HPeAIManaged](https://developers.hp.com/hp-client-management/doc/Set-HPeAIManaged)
#>
function Get-HPeAIManaged {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-HPeAIManaged")]
  param()
  $eAIRegPath = 'HKLM:\Software\Policies\HP\SmartExperiences'

  if ((Test-HPSmartExperiencesIsSupported) -eq $false) {
    throw [System.NotSupportedException]"HP Smart Experiences is currently not supported on this platform."
  }

  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

  Write-Verbose "Reading $eAIRegPath\Managed"
  $reg = Get-ItemProperty -Path $eAIRegPath -ErrorAction SilentlyContinue -Name Managed

  if ($reg) {
    return ($reg.Managed -eq 1)
  }

  return $false
}

<#
.SYNOPSIS
  Configures HP eAI features on the current device

.DESCRIPTION
  Configures HP eAI features on the current device. At this time, only the 'Privacy Alert' feature and the 'Auto Screen Dimming' feature are available to be configured. 

.PARAMETER Name
  Specifies the eAI feature name to configure. The value must be one of the following values:
  - Privacy Alert
  - Auto Screen Dimming

.PARAMETER Enabled
  If set to $true, this command will enable the feature specified in the Name parameter. If set to $false, this command will disable the feature specified in the -Name parameter. 

.PARAMETER AllowEdit
  If set to $true, editing is allowed for the feature specified in the Name parameter. If set to $false, editing is not allowed for the feature specified in the -Name parameter.

.PARAMETER Default
  Sets default value of the feature specified in the -Name parameter. The value must be one of the following values:
  - On
  - Off

.EXAMPLE
  Set-HPeAISettingValue -Name 'Privacy Alert' -Enabled $true -Default 'On' -AllowEdit $false

.EXAMPLE
  Set-HPeAISettingValue -Name 'Privacy Alert' -Enabled $true

.EXAMPLE
  Set-HPeAISettingValue -Name 'Auto Screen Dimming' -Default 'On'

.EXAMPLE
  Set-HPeAISettingValue -Name 'Auto Screen Dimming' -AllowEdit $false

.NOTES
  Admin privilege is required.

.LINK
  [Set-HPeAIManaged](https://developers.hp.com/hp-client-management/doc/Set-HPeAIManaged)

.LINK
  [Get-HPeAISettingValue](https://developers.hp.com/hp-client-management/doc/Get-HPeAISettingValue)
#>
function Set-HPeAISettingValue {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Set-HPeAISettingValue")]
  param(
    [Parameter(Mandatory = $true,Position = 0,ParameterSetName = 'Enabled')]
    [Parameter(Mandatory = $true,Position = 0,ParameterSetName = 'AllowEdit')]
    [Parameter(Mandatory = $true,Position = 0,ParameterSetName = 'Default')]
    [ValidateSet('Privacy Alert','Auto Screen Dimming')]
    [string]$Name,

    [Parameter(Mandatory = $true,Position = 1,ParameterSetName = 'Enabled')]
    [bool]$Enabled,

    [Parameter(Mandatory = $false,Position = 2,ParameterSetName = 'Enabled')]
    [Parameter(Mandatory = $true,Position = 1,ParameterSetName = 'AllowEdit')]
    [bool]$AllowEdit,

    [Parameter(Mandatory = $false,Position = 3,ParameterSetName = 'Enabled')]
    [Parameter(Mandatory = $false,Position = 2,ParameterSetName = 'AllowEdit')]
    [Parameter(Mandatory = $true,Position = 1,ParameterSetName = 'Default')]
    [ValidateSet('On','Off')]
    [string]$Default
  )
  $eAIFeatures = @{
    'Privacy Alert' = 'shoulderSurf'
    'Auto Screen Dimming' = 'attentionDim'
  }
  $eAIRegPath = 'HKLM:\Software\Policies\HP\SmartExperiences'

  if ((Test-HPSmartExperiencesIsSupported) -eq $false) {
    throw [System.NotSupportedException]"HP Smart Experiences is currently not supported on this platform."
  }

  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

  Write-Verbose "Reading registry path $eAIRegPath\Policy"
  $reg = Get-ItemProperty -Path $eAIRegPath -ErrorAction SilentlyContinue -Name Policy
  if ($reg) {
    try {
      Write-Verbose "Data read: $($reg.Policy)"
      $current = $reg.Policy | ConvertFrom-Json
    }
    catch {
      throw [System.FormatException]"$($_.Exception.Message): Please ensure Policy property contains a valid JSON."
    }
  }
  else {
    $current = [ordered]@{
      attentionDim = [ordered]@{
        allowEdit = $true
        default = 0
        isEnabled = $false
      }
      shoulderSurf = [ordered]@{
        allowEdit = $true
        default = 0
        isEnabled = $false
      }
    }
    Write-Verbose "Creating registry entry with the default values to $eAIRegPath"
    New-Item -Path $eAIRegPath -Force | Out-Null
  }

  Write-Verbose "$($eAIFeatures[$Name]) selected"
  $config = $current.$($eAIFeatures[$Name])
  if ($PSBoundParameters.Keys.Contains('Enabled')) {
    $config.isEnabled = $Enabled
  }
  if ($PSBoundParameters.Keys.Contains('AllowEdit')) {
    $config.allowEdit = $AllowEdit
  }
  if ($PSBoundParameters.Keys.Contains('Default')) {
    $config.default = if ($Default -eq 'On') { 1 } else { 0 }
  }

  $value = $current | ConvertTo-Json -Compress
  Write-Verbose "Setting $eAIRegPath\Policy to $value"

  if ($reg) {
    Set-ItemProperty -Path $eAIRegPath -Value $value -Name Policy -Force | Out-Null
  }
  else {
    New-ItemProperty -Path $eAIRegPath -Value $value -Name Policy -Force | Out-Null
  }

  $reg = Get-ItemProperty -Path $eAIRegPath -ErrorAction SilentlyContinue -Name Managed
  if ($reg) {
    $managed = $reg.Managed
  }
  else {
    $managed = 0
    Write-Verbose "Creating registry entry $eAIRegPath\Managed with default value $managed"
    New-ItemProperty -Path $eAIRegPath -Value $managed -Name Managed -Force | Out-Null
  }
  if ($managed -eq 0) {
    Write-Warning "eAI managed attribute has not been set. Refer to Set-HPeAIManaged function documentation on how to set it."
  }
}

<#
.SYNOPSIS
  Checks if Smart Experiences is supported on the current device

.DESCRIPTION
  This command checks if the BIOS setting "HP Smart Experiences" exists to determine if Smart Experiences is supported on the current device.

.EXAMPLE
  Test-HPSmartExperiencesIsSupported

.LINK
  [Get-HPeAISettingValue](https://developers.hp.com/hp-client-management/doc/Get-HPeAISettingValue)

.LINK
  [Set-HPeAISettingValue](https://developers.hp.com/hp-client-management/doc/Set-HPeAISettingValue)

.LINK
  [Set-HPeAIManaged](https://developers.hp.com/hp-client-management/doc/Set-HPeAIManaged)
#>
function Test-HPSmartExperiencesIsSupported {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Test-HPSmartExperiencesIsSupported")]
  param()

  [boolean]$status = $false
  try {
    $mode = (Get-HPBIOSSettingValue -Name "HP Smart Experiences")
    $status = $true
  }
  catch {}

  return $status
}

<#
.SYNOPSIS
  Retrieves the values of the specified HP eAI feature from the current device

.DESCRIPTION
  This command retrieves the values of the specified HP eAI feature where the feature must be from the current device. The feature must be either 'Privacy Alert' or 'Auto Screen Dimming'.

.PARAMETER Name
  Specifies the eAI feature to read. The value must be one of the following values:
  - Privacy Alert
  - Auto Screen Dimming

.EXAMPLE
  Get-HPeAISettingValue -Name 'Privacy Alert'

.EXAMPLE
  Get-HPeAISettingValue -Name 'Auto Screen Dimming'

.NOTES
  Admin privilege is required.

.LINK
  [Set-HPeAISettingValue](https://developers.hp.com/hp-client-management/doc/Set-HPeAISettingValue)

.LINK
  [Set-HPeAIManaged](https://developers.hp.com/hp-client-management/doc/Set-HPeAIManaged)
#>
function Get-HPeAISettingValue {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-HPeAISettingValue")]
  param(
    [Parameter(Mandatory = $true,Position = 0)]
    [ValidateSet('Privacy Alert','Auto Screen Dimming')]
    [string]$Name
  )
  $eAIFeatures = @{
    'Privacy Alert' = 'shoulderSurf'
    'Auto Screen Dimming' = 'attentionDim'
  }
  $eAIRegPath = 'HKLM:\Software\Policies\HP\SmartExperiences'

  if ((Test-HPSmartExperiencesIsSupported) -eq $false) {
    throw [System.NotSupportedException]"HP Smart Experiences is currently not supported on this platform."
  }

  Write-Verbose "Reading registry path $eAIRegPath\Policy"
  $reg = Get-ItemProperty -Path $eAIRegPath -ErrorAction SilentlyContinue -Name Policy
  if (-not $reg) {
    throw [System.InvalidOperationException]'HP eAI is not currently configured on your device.'
  }
  else {
    try {
      Write-Verbose "Data read: $($reg.Policy)"
      $current = $reg.Policy | ConvertFrom-Json
    }
    catch {
      throw [System.FormatException]"$($_.Exception.Message): Please ensure Policy property contains a valid JSON."
    }
    Write-Verbose "$($eAIFeatures[$Name]) selected"
    $config = $current.$($eAIFeatures[$Name])

    $reg = Get-ItemProperty -Path $eAIRegPath -ErrorAction SilentlyContinue -Name Managed
    if ($reg) {
      $managed = $reg.Managed
    }
    else {
      $managed = $false
    }
    Write-Verbose "Managed: $managed"

    return [ordered]@{
      Enabled = [bool]$config.isEnabled
      Default = if ($config.default -eq 1) { 'On' } else { 'Off' }
      AllowEdit = [bool]$config.allowEdit
    }
  }
}
# SIG # Begin signature block
# MIIoFwYJKoZIhvcNAQcCoIIoCDCCKAQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD+zdIXquO7YMDR
# GFZo5716vczwSbHf5W7BzvHLkEW9k6CCDYowggawMIIEmKADAgECAhAIrUCyYNKc
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIG3E5D4F
# piA2/YErt8Qydv9icCvR5FyGzPBa13rZG6PoMA0GCSqGSIb3DQEBAQUABIIBgHTd
# fR0pHb1x/wWsLPDBDeM3+nbjFlRtstxwRUi8QwtFwNfRizDG853kDaF51l8m7xp/
# 4HJiR1TaSk3ULsLMZiy1m4S5Cl+HEJ86D5RLY95vWVVmknf1TxyhAlpskIhy4CFZ
# uKjayQEeeQtlD0v8wluFOaVjkleUWZ5z6k/q5IA2THL+LSsk2YkOqyzTiU4cktz0
# 9TwHEZi5jndLhvyefRa4VnrNHsY/Mb+j7DOMnYn4kE1p+7hhp3hRGPp/G3R5krMr
# 3bd2QaI7APLB+fqb7kgcikg2zWG3BqF99c0x3XE/vSsOhF/Au5pMBoLarZcyWwcK
# Va0nskLBrV+ZYw61s9DcMaglqN/s8D9y/+XTaliSz/FMBGM+6hnB/u9IU+b3ZXVL
# www8NSAJyXe7C4EVM7QmsEDrMbNOjQQikzHDSkYDqR8Ir+2sNmsqJPJRzwLvgoZO
# h0F0T01GleZ2NU1pBGeaRUrE365vZT0ar5kc2syzVrPYvfLso1HzN2H1QeYkz6GC
# Fzkwghc1BgorBgEEAYI3AwMBMYIXJTCCFyEGCSqGSIb3DQEHAqCCFxIwghcOAgED
# MQ8wDQYJYIZIAWUDBAIBBQAwdwYLKoZIhvcNAQkQAQSgaARmMGQCAQEGCWCGSAGG
# /WwHATAxMA0GCWCGSAFlAwQCAQUABCDBxXJJKi+qGczNyLFe69bMRr6daAFjBd90
# q1OvJMkG8gIQd5pBm8gWTChi5am3YT8RxRgPMjAyNTA0MTcxODQ4NTFaoIITAzCC
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
# EAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MTcxODQ4NTFaMCsGCyqGSIb3DQEJEAIM
# MRwwGjAYMBYEFNvThe5i29I+e+T2cUhQhyTVhltFMC8GCSqGSIb3DQEJBDEiBCBQ
# dY3bmk0zscAh3RYCypFRutCqjcTYlSbmgUyUC0flrTA3BgsqhkiG9w0BCRACLzEo
# MCYwJDAiBCB2dp+o8mMvH0MLOiMwrtZWdf7Xc9sF1mW5BZOYQ4+a2zANBgkqhkiG
# 9w0BAQEFAASCAgCmYplmWbaDB/qnNH+Zxip70CeKMN3a1JymZUrSVjru2sOSlZBQ
# euJrd92fN9kpNzgspPesTRL+SYx9bG0b8WACf2qJ096FFnG+9mWkOCuzfTIhl5Mo
# JJnxNKFsxQDmDA3utcefq+nh/9RGz8I/GoXp4hsUjb4LaD79J1DvJAZdCqfasJR9
# 01w0nR9OFRY5FrnLTvZfH8hQidc9qI7JJCJ9RFoi0FyfaGqvyF9uCGB+e2Tm61y8
# GsJZHW74o3z8YPFR1oMGjVPxK5EBXCnK5q21AhCzz09oWN+y6+r7+MQ0pADAnwwM
# Q3nWulbN5ExyzmtzgjOgKr5jfht+gbTo0MbjDR2MOFIf4c58Ci3QR9VgJbEiJee6
# AcGrm3OVxsFUxhTzkCidDy55OiTd8JKY5XPvdc5rtGDFpWAO3K/EjQGzkyG7PlGx
# UhjRAH2UAcdUbKTYGDUtwNjHpak6E+kp5vrBOBNWY5jv4OtvwEsM68PvwTFRdyfa
# 3sr3r589ZGJPdUtu3Wr8BNGZvdngp533yRzR5ZA6eCD6c77MwH8VtwKfiAj8zOPk
# Ybms8Yq3IeaSp0zaggi/kV5hgTNtUq0MmENeC+R1ZZiZHqRNVHOCR/p2OR6gSFOe
# u6LGVsz9BAhRQaORLRA28KSLDTBvQZUC1yU3NO6Zi+3DHVq69el2KDi6Jg==
# SIG # End signature block
