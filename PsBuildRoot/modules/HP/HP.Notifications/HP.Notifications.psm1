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

# For PS7, PSEdition is Core and for PS5.1, PSEdition is Desktop
if ($PSEdition -eq "Core") {
  Add-Type -Assembly $PSScriptRoot\refs\WinRT.Runtime.dll
  Add-Type -Assembly $PSScriptRoot\refs\Microsoft.Windows.SDK.NET.dll
}
else {
  [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
  [void][Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications,  ContentType = WindowsRuntime]
  [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
}

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
    Creates a logo object
    .DESCRIPTION
    This command creates a toaster logo from a file image.
    .PARAMETER Image
    Specifies the URL to the image.Http images must be 200 KB or less in size. Not all URL formats are supported in all scenarios.
    .PARAMETER Crop
    Specifies how you would like the image to be cropped.
    .EXAMPLE
    PS>  $logo = New-HPPrivateToastNotificationLogo .\logo.png
    .OUTPUTS
    This command returns the object representing the logo image.
#>
function New-HPPrivateToastNotificationLogo
{
  param(
    [Parameter(Position = 0,Mandatory = $True,ValueFromPipeline = $True)]
    [System.IO.FileInfo]$Image,

    [Parameter(Position = 1,Mandatory = $False)]
    [ValidateSet('None','Default','Circle')]
    [string]$Crop
  )

  [xml]$xml = New-Object System.Xml.XmlDocument
  $child = $xml.CreateElement("image")
  $child.SetAttribute('src',$Image.FullName)
  $child.SetAttribute('placement','appLogoOverride')
  if ($Crop) { $child.SetAttribute('hint-crop',$Crop.ToLower()) }
  $child
}

<#
    .SYNOPSIS
    Creates a toast image object
    .DESCRIPTION
    This command creates a toaster image from a file image. This image may be shown in the body of a toast message.
    .PARAMETER Image
    Specifies the URL to the image. Http images must be 200 KB or less in size.  Not all URL formats are supported in all scenarios.
    .PARAMETER Position
     Specifies that toasts can display a 'fixed' image, which is a featured ToastGenericHeroImage displayed prominently within the toast banner and while inside Action Center. Image dimensions are 364x180 pixels at 100% scaling.
     Alternately, use 'inline' to display a full-width inline-image that appears when you expand the toast.

    .EXAMPLE
    PS>  $logo = New-HPPrivateToastNotificationLogo .\hero.png
    .OUTPUTS
    This function returns the object representing the image.
    .LINK
    [ToastGenericHeroImage](https://docs.microsoft.com/en-us/windows/uwp/design/shell/tiles-and-notifications/toast-schema#toastgenericheroimage)
#>
function New-HPPrivateToastNotificationImage
{
  param(
    [Parameter(Position = 0,Mandatory = $True,ValueFromPipeline = $True)]
    [string]$Image,
    [Parameter(Position = 1,Mandatory = $False)]
    [ValidateSet('Inline','Fixed')]
    [string]$Position = 'Fixed'
  )
  [xml]$xml = New-Object System.Xml.XmlDocument
  $child = $xml.CreateElement("image")
  $child.SetAttribute('src',$Image)
  #$child.SetAttribute('placement','appLogoOverride') is this needed?

  if ($Position -eq 'Fixed') {
    $child.SetAttribute('placement','hero')
  }
  else
  {
    $child.SetAttribute('placement','inline')
  }
  $child
}

<#
    .SYNOPSIS
    Specifies the toast message alert sound
    .DESCRIPTION
    This command allows defining the sound to play on toast notification.
    .PARAMETER Sound
    Specifies the sound to play
    .PARAMETER Loop
    If specified, the sound will be looped

    .EXAMPLE
    PS>  $logo = New-HPPrivateToastSoundPreference -Sound "Alarm6" -Loop
    .OUTPUTS
    This function returns the object representing the sound preference.
    .LINK
    [ToastAudio](https://docs.microsoft.com/en-us/windows/uwp/design/shell/tiles-and-notifications/toast-schema#ToastAudio)
#>
function New-HPPrivateToastSoundPreference
{
  param(
    [Parameter(Position = 1,Mandatory = $False)]
    [ValidateSet('None','Default','IM','Mail','Reminder','SMS',
      'Alarm','Alarm2','Alarm3','Alarm4','Alarm5','Alarm6','Alarm7','Alarm8','Alarm9','Alarm10',
      'Call','Call2','Call3','Call4','Call5','Call6','Call7','Call8','Call9','Call10')]
    [string]$Sound = "Default",
    [Parameter(Position = 2,Mandatory = $False)]
    [switch]$Loop
  )
  [xml]$xml = New-Object System.Xml.XmlDocument
  $child = $xml.CreateElement("audio")
  if ($Sound -eq "None") {
    $child.SetAttribute('silent',"$true".ToLower())
    Write-Verbose "Setting audio notification to Muted"
  }
  else
  {
    $soundPath = "ms-winsoundevent:Notification.$Sound"
    if ($Sound.StartsWith('Alarm') -or $Sound.StartsWith('Call'))
    {
      $soundPath = 'winsoundevent:Notification.Looping.' + $Sound
    }
    Write-Verbose "Setting audio notification to: $soundPath"
    $child.SetAttribute('src',$soundPath)
    $child.SetAttribute('loop',([string]$Loop.IsPresent).ToLower())
    Write-Verbose "Looping audio: $($Loop.IsPresent)"
  }
  $child
}

<#
    .SYNOPSIS
    Creates a toast button
    .DESCRIPTION
    Creates a toast button for the toast
    .PARAMETER Sound
    Specifies the sound to play
    .PARAMETER Image
    Specifies the button image for a graphical button
    .PARAMETER Arguments
    Specifies app-defined string of arguments that the app will later receive if the user clicks this button.
    .OUTPUTS
    This command returns the object representing the button
    .LINK
    [ToastButton](https://docs.microsoft.com/en-us/windows/uwp/design/shell/tiles-and-notifications/toast-schema#ToastButton)
#>
function New-HPPrivateToastButton
{
    [Cmdletbinding()]
    param(
        [string]$Caption,
        [string]$Image, # leave out for normal button
        [string]$Arguments,
        [ValidateSet('Background','Protocol','System')]
        [string]$ActivationType = 'background'
    )

    Write-Verbose "Creating new toast button with caption $Caption"
    if ($Image) {
        ([xml]"<action content=`"$Caption`" imageUri=`"$Image`" arguments=`"$Arguments`" activationType=`"$ActivationType`" />").DocumentElement
    } else {
        ([xml]"<action content=`"$Caption`" arguments=`"$Arguments`" activationType=`"$ActivationType`" />").DocumentElement

    }
}

<#
  .SYNOPSIS
  Create a toast action

  .DESCRIPTION
  Create a toast action for the toast

  .PARAMETER SnoozeOrDismiss
  Automatically constructs a selection box for snooze intervals, and snooze/dismiss buttons, all automatically localized, and snoozing logic is automatically handled by the system.

  .PARAMETER Image
  For a graphical button, specify the button image

  .PARAMETER Arguments
  App-defined string of arguments that the app will later receive if the user clicks this button.

  .OUTPUTS
  This function returns the object representing the button
#>
function New-HPPrivateToastActions
{
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = 'DismissSuppress',Position = 1,Mandatory = $True)]
    [switch]$SnoozeOrDismiss,

    [Parameter(ParameterSetName = 'DismissSuppress',Position = 2,Mandatory = $True)]
    [int]$SnoozeMinutesDefault,

    [Parameter(ParameterSetName = 'DismissSuppress',Position = 3,Mandatory = $True)]
    [int[]]$SnoozeMinutesOptions,

    [Parameter(ParameterSetName = 'CustomButtons',Position = 1,Mandatory = $True)]
    [switch]$CustomButtons,

    [Parameter(ParameterSetName = 'CustomButtons',Position = 2,Mandatory = $false)]
    [System.Xml.XmlElement[]]$Buttons,

    [Parameter(ParameterSetName = 'CustomButtons',Position = 3,Mandatory = $false)]
    [switch]$NoDismiss

  )
  [xml]$xml = New-Object System.Xml.XmlDocument
  $child = $xml.CreateElement("actions")

  switch ($PSCmdlet.ParameterSetName) {
    'DismissSuppress' {
      Write-Verbose "Creating system-handled snoozable notification"

      $i = $xml.CreateElement("input")
      [void]$child.AppendChild($i)

      $i.SetAttribute('id',"snoozeTime")
      $i.SetAttribute('type','selection')
      $i.SetAttribute('defaultInput',$SnoozeMinutesDefault)

      Write-Verbose "Notification snooze default: SnoozeMinutesDefault"
      $SnoozeMinutesOptions | ForEach-Object {
        $s = $xml.CreateElement("selection")
        $s.SetAttribute('id',"$_")
        $s.SetAttribute('content',"$_ minute")
        [void]$i.AppendChild($s)
      }

      $action = $xml.CreateElement("action")
      $action.SetAttribute('activationType','system')
      $action.SetAttribute('arguments','snooze')
      $action.SetAttribute('hint-inputId','snoozeTime')
      $action.SetAttribute('content','Snooze')
      [void]$child.AppendChild($action)

      Write-Verbose "Creating custom buttons toast"
      if ($Buttons) {
        $Buttons | ForEach-Object {
          $node = $xml.ImportNode($_,$true)
          [void]$child.AppendChild($node)
        }
      }

      $action = $xml.CreateElement("action")
      $action.SetAttribute('activationType','system')
      $action.SetAttribute('arguments','dismiss')
      $action.SetAttribute('content','Dismiss')
      [void]$child.AppendChild($action)
    }

    'CustomButtons' { # customized buttons
      Write-Verbose "Creating custom buttons toast"

      if($Buttons) {
        $Buttons | ForEach-Object {
          $node = $xml.ImportNode($_,$true)
          [void]$child.AppendChild($node)
        }
      }

      if (-not $NoDismiss.IsPresent) {
        $action = $xml.CreateElement("action")
        $action.SetAttribute('activationType','system')
        $action.SetAttribute('arguments','dismiss')
        $action.SetAttribute('content','Dismiss')
        [void]$child.AppendChild($action)
      }
    }

    default {

    }
  }

  $child
}

<#
    .SYNOPSIS
    Shows a toast message
    .DESCRIPTION
    This command shows a toast message, and optionally registers a response handler.
    .PARAMETER Message
    Specifies the message to show
    .PARAMETER Title
    Specifies title of the message to show
    .PARAMETER Logo
    Specifies a logo object created with New-HPPrivateToastNotificationLogo
    .PARAMETER Image
    Specifies a logo object created with New-HPPrivateToastNotificationImage
    .PARAMETER Expiration
    Specifies a timeout in minutes for the toast to remove itself
    .PARAMETER Tag
    Specifies a tag value for the toast. Please note that if a toast with the same tag already exists, it will be replaced by this one.
    .PARAMETER Group
    Specifies a group value for the toast
    .PARAMETER Attribution
    Specifies toast owner
    .PARAMETER Sound
    Specifies a sound notification preference created with New-HPPrivateToastSoundPreference
    .PARAMETER Actions
    .PARAMETER Persist
#>
function New-HPPrivateToastNotification
{
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = 'TextOnly',Position = 0,Mandatory = $False,ValueFromPipeline = $True)]
    [string]$Message,

    [Parameter(Position = 1,Mandatory = $False)]
    [string]$Title,

    [Parameter(Position = 3,Mandatory = $False)]
    [System.Xml.XmlElement]$Logo,

    [Parameter(Position = 4,Mandatory = $False)]
    [int]$Expiration,

    [Parameter(Position = 5,Mandatory = $False)]
    [string]$Tag,

    [Parameter(Position = 6,Mandatory = $False)]
    [string]$Group = "hp-cmsl",

    [Parameter(Position = 8,Mandatory = $False)]
    [System.Xml.XmlElement]$Sound,

    # Apparently can't do URLs with non-uwp
    [Parameter(Position = 11,Mandatory = $False)]
    [System.Xml.XmlElement]$Image,

    [Parameter(Position = 13,Mandatory = $False)]
    [System.Xml.XmlElement]$Actions,

    [Parameter(Position = 14,Mandatory = $False)]
    [switch]$Persist,

    [Parameter(Position = 15 , Mandatory = $False)]
    [string]$Signature,

    [Parameter(Position = 16,Mandatory = $False)]
    [System.IO.FileInfo]$Xml
  )
  # if $Xml is given, load the xml instead of manually creating it
  if ($Xml) {
    Write-Verbose "Loading XML from $Xml"
    try {
      [xml]$xml = Get-Content $Xml
    } catch {
      Write-Error "Failed to load schema XML from $Xml"
      return
    }
  } else {

    # In order for signature text to be smaller, we have to add placement="attribution" to the text node. 
    # When using placement="attribution", Signature text will always be displayed at the bottom of the toast notification, 
    # along with the app's identity or the notification's timestamp if we were to customize the notification to provide these as well. 
    # On older versions of Windows that don't support attribution text, the text will simply be displayed as another text element 
    # (assuming we don't already have the maximum of three text elements, 
    # but we currently only have Invoke-HPNotification showing up to 3 text elements with the 3rd for $Signature being smallest)
    [xml]$xml = '<toast><visual><binding template="ToastGeneric"><text></text><text></text><text placement="attribution"></text></binding></visual></toast>'

    $binding = $xml.GetElementsByTagName("toast")
    if ($Sound) {
      $node = $xml.ImportNode($Sound,$true)
      [void]$binding.AppendChild($node)
    }

    if ($Persist.IsPresent)
    {
      $binding.SetAttribute('scenario','reminder')
    }

    if ($Actions) {
      $node = $xml.ImportNode($Actions,$true)
      [void]$binding.AppendChild($node)
    }

    $binding = $xml.GetElementsByTagName("binding")
    if ($Logo) {
      $node = $xml.ImportNode($Logo,$true)
      [void]$binding.AppendChild($node)
    }

    if ($Image) {
      $node = $xml.ImportNode($Image,$true)
      [void]$binding.AppendChild($node)
    }

    $binding = $xml.GetElementsByTagName("text")
    if ($Title) {
      [void]$binding[0].AppendChild($xml.CreateTextNode($Title.trim()))
    }

    [void]$binding[1].AppendChild($xml.CreateTextNode($Message.trim()))

    if ($Signature){
      [void]$binding[2].AppendChild($xml.CreateTextNode($Signature.trim()))
    }
  }

  Write-Verbose "Submitting toast with XML: $($xml.OuterXml)"
  $toast = [Windows.Data.Xml.Dom.XmlDocument]::new()
  $toast.LoadXml($xml.OuterXml)

  $toast = [Windows.UI.Notifications.ToastNotification]::new($toast)

  # if you specify a non-unique tag, it will replace the previous toast with the same non-unique tag
  if($Tag) {
    $toast.Tag = $Tag
  }

  $toast.Group = $Group

  if ($Expiration) {
    $toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes($Expiration)
  }

  return $toast
}

function Show-ToastNotification {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0,Mandatory = $False,ValueFromPipeline = $true)]
    $Toast,

    [Parameter(Position = 1,Mandatory = $False)]
    [string]$Attribution = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
  )

  $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($Attribution)
  $notifier.Show($toast)
}

function Register-HPPrivateScriptProtocol {
  [CmdletBinding()]
  param(
    [string]$ScriptPath,
    [string]$Name
  )

  try {
    New-Item "HKCU:\Software\Classes\$($Name)\shell\open\command" -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -LiteralPath "HKCU:\Software\Classes\$($Name)" -Name 'URL Protocol' -Value '' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -LiteralPath "HKCU:\Software\Classes\$($Name)" -Name '(default)' -Value "url:$($Name)" -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -LiteralPath "HKCU:\Software\Classes\$($Name)" -Name 'EditFlags' -Value 2162688 -PropertyType Dword -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -LiteralPath "HKCU:\Software\Classes\$($Name)\shell\open\command" -Name '(default)' -Value $ScriptPath -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
  }
  catch {
    Write-Host $_.Exception.Message
  }
}


<#
.SYNOPSIS
  This is a private command for internal use only

.DESCRIPTION
  This is a private command for internal use only

.EXAMPLE

.NOTES
  - This is a private command for internal use only
#>
function Invoke-HPPrivateRebootNotificationAsUser {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0,Mandatory = $false)]
    [string]$Title = "A System Reboot is Required",

    [Parameter(Position = 1,Mandatory = $false)]
    [string]$Message = "Please reboot now to keep your device compliant with the security policies.",

    [Parameter(Position = 2,Mandatory = $false)]
    [System.IO.FileInfo]$LogoImage,

    [Parameter(Position = 4,Mandatory = $false)]
    [int]$Expiration = 0,

    [Parameter(Position = 4,Mandatory = $False)]
    [string]$Attribution
  )

  # Use System Root instead of hardcoded path to C:\Windows
  Register-HPPrivateScriptProtocol -ScriptPath "$env:SystemRoot\System32\shutdown.exe -r -t 0 -f" -Name "rebootnow"

  $rebootButton = New-HPPrivateToastButton -Caption "Reboot now" -Image $null -Arguments "rebootnow:" -ActivationType "Protocol"

  $params = @{
    Message = $Message
    Title = $Title
    Expiration = $Expiration
    Actions = New-HPPrivateToastActions -CustomButtons -Buttons $rebootButton
    Sound = New-HPPrivateToastSoundPreference -Sound IM
  }

  if ($LogoImage) {
    $params.Logo = New-HPPrivateToastNotificationLogo -Image $LogoImage -Crop Circle
  }

  $toast = New-HPPrivateToastNotification @params -Persist

  if ($toast) {
    if ([string]::IsNullOrEmpty($Attribution)) {
      Show-ToastNotification -Toast $toast
    }
    else {
      Show-ToastNotification -Toast $toast -Attribution $Attribution
    }
  }

  return
}

<#
.SYNOPSIS
  This is a private command for internal use only

.DESCRIPTION
  This is a private command for internal use only

.EXAMPLE

.NOTES
  - This is a private command for internal use only
#>
function Invoke-HPPrivateNotificationAsUser {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0,Mandatory = $false)]
    [string]$Title,

    [Parameter(Position = 1,Mandatory = $false)]
    [string]$Message,

    [Parameter(Position = 2,Mandatory = $false)]
    [System.IO.FileInfo]$LogoImage,

    [Parameter(Position = 4,Mandatory = $false)]
    [int]$Expiration = 0,

    [Parameter(Position = 4,Mandatory = $False)]
    [string]$Attribution,

    [Parameter(Position = 5,Mandatory = $false)]
    [string]$NoDismiss = "false", # environment variables can only be strings, so Dismiss parameter is a string

    [Parameter(Position = 6,Mandatory = $false)]
    [string]$Signature,

    [Parameter(Position = 7,Mandatory = $false)]
    [System.IO.FileInfo]$Xml,

    [Parameter(Position = 8,Mandatory = $false)]
    [System.IO.FileInfo]$Actions
  )

  if ($Xml){
    if($Actions){
      # parse the file of Actions to get the actions to register 
      try {
       $listOfActions = Get-Content $Actions | ConvertFrom-Json
      }
      catch {
       Write-Error "Failed to parse the file of actions: $($_.Exception.Message). Will not proceed with invoking notification."
       return
      }

      # register every action in list of actions 
      foreach ($action in $listOfActions) {
       Register-HPPrivateScriptProtocol -ScriptPath $action.cmd -Name $action.id
      }

      Write-Verbose "Done registering actions"
    }
    
    $toast = New-HPPrivateToastNotification -Expiration $Expiration -Xml $Xml -Persist

   if ($toast) {
     if ([string]::IsNullOrEmpty($Attribution)) {
       Show-ToastNotification -Toast $toast
     }
     else {
       Show-ToastNotification -Toast $toast -Attribution $Attribution
     }
   }
  }
  else{
    $params = @{
      Message = $Message
      Title = $Title
      Expiration = $Expiration
      Signature = $Signature
      Sound = New-HPPrivateToastSoundPreference -Sound IM
    }
  
    # environment variables can only be strings, so Dismiss parameter is a string
    if ($NoDismiss -eq "false") {
      $params.Actions = New-HPPrivateToastActions -CustomButtons
    }
    else {
      $params.Actions = New-HPPrivateToastActions -CustomButtons -NoDismiss
    }
  
    if ($LogoImage) {
      $params.Logo = New-HPPrivateToastNotificationLogo -Image $LogoImage -Crop Circle
    }
  
    $toast = New-HPPrivateToastNotification @params -Persist
  
    if ([string]::IsNullOrEmpty($Attribution)) {
      Show-ToastNotification -Toast $toast
    }
    else {
      Show-ToastNotification -Toast $toast -Attribution $Attribution
    }
  }

  return 
}

<#
.SYNOPSIS
  Register-NotificationApplication

.DESCRIPTION
  This function registers toast notification applications

.PARAMETER Id
  Specifies the application id

.PARAMETER DisplayName
  Specifies the application name to display on the toast notification

.EXAMPLE
  Register-NotificationApplication -Id 'hp.cmsl.12345' -DisplayName 'HP CMSL'
#>
function Register-NotificationApplication {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory=$true)]
      [string]$Id,

      [Parameter(Mandatory=$true)]
      [string]$DisplayName,

      [Parameter(Mandatory=$false)]
      [System.IO.FileInfo]$IconPath
  )
  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

  Write-Verbose "Registering notification application with id: $Id and display name: $DisplayName and icon path: $IconPath"

  $drive = Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue
  if (-not $drive) {
    $drive = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Scope Script
  }
  $appRegPath = Join-Path -Path "$($drive):" -ChildPath 'AppUserModelId'
  $regPath = Join-Path -Path $appRegPath -ChildPath $Id
  if (-not (Test-Path $regPath))
  {
    New-Item -Path $appRegPath -Name $Id -Force | Out-Null
  }
  $currentDisplayName = Get-ItemProperty -Path $regPath -Name DisplayName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName -ErrorAction SilentlyContinue
  if ($currentDisplayName -ne $DisplayName) {
    New-ItemProperty -Path $regPath -Name DisplayName -Value $DisplayName -PropertyType String -Force | Out-Null
  }

  New-ItemProperty -Path $regPath -Name IconUri -Value $IconPath -PropertyType ExpandString -Force | Out-Null	
  New-ItemProperty -Path $regPath -Name IconBackgroundColor -Value 0 -PropertyType ExpandString -Force | Out-Null
  Remove-PSDrive -Name HKCR -Force

  Write-Verbose "Registered toast notification application: $DisplayName"
}

<#
.SYNOPSIS
  Unregister-NotificationApplication

.DESCRIPTION
  This function unregisters toast notification applications. Do not unregister the application if you want to snooze the notification.

.PARAMETER Id
  Specifies the application ID to unregister 

.EXAMPLE
  Unregister-NotificationApplication -Id 'hp.cmsl.12345'
#>
function Unregister-NotificationApplication {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory=$true)]
      $Id
  )
  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

  $drive = Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue
  if (-not $drive) {
    $drive = New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Scope Script
  }
  $appRegPath = Join-Path -Path "$($drive):" -ChildPath 'AppUserModelId'
  $regPath = Join-Path -Path $appRegPath -ChildPath $Id
  if (Test-Path $regPath) {
    Remove-Item -Path $regPath
  }
  else {
    Write-Verbose "Application not found at $regPath"
  }
  Remove-PSDrive -Name HKCR -Force

  Write-Verbose "Unregistered toast notification application: $Id"
}

<#
.SYNOPSIS
  Invoke-HPRebootNotification

.DESCRIPTION
  This command shows a toast message asking the user to reboot the system. 

.PARAMETER Message
  Specifies the message to show

.PARAMETER Title
  Specifies the title of the message to show

.PARAMETER LogoImage
  Specifies the image file path to be displayed

.PARAMETER Expiration
  Specifies the timeout in minutes for the toast to remove itself. If not specified, the toast remains until dismissed.

.PARAMETER TitleBarHeader
  Specifies the text of the toast notification in the title bar. If not specified, the text will default to "HP System Update". 

.PARAMETER TitleBarIcon
  Specifies the icon of the toast notification in the title bar. If not specified, the icon will default to the HP logo. Please note that the color of the icon might be inverted depending on the background color of the title bar.


.EXAMPLE
  Invoke-HPRebootNotification -Title "My title" -Message "My message"
#>
function Invoke-HPRebootNotification {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Invoke-RebootNotification")]
  [Alias("Invoke-RebootNotification")] # we can deprecate Invoke-RebootNotification later 
  param(
    [Parameter(Position = 0,Mandatory = $False)]
    [string]$Title = "A System Reboot Is Required",

    [Parameter(Position = 1,Mandatory = $False)]
    [string]$Message = "Please reboot now to keep your device compliant with organizational policies.",

    [Parameter(Position = 2,Mandatory = $false)]
    [System.IO.FileInfo]$LogoImage,

    [Parameter(Position = 3,Mandatory = $false)]
    [int]$Expiration = 0,

    [Parameter(Position = 4,Mandatory = $false)]
    [string]$TitleBarHeader = "HP System Update", # we don't want to display "Windows PowerShell" in the title bar

    [Parameter(Position = 5,Mandatory = $false)]
    [System.IO.FileInfo]$TitleBarIcon = (Join-Path -Path $PSScriptRoot -ChildPath 'assets\hp_black_logo.png') # default to HP logo 
  )

  # Create a unique Id to distinguish this notification application from others using "hp.cmsl" and the current time
  $Id = "hp.cmsl.$([DateTime]::Now.Ticks)"

  # Convert the relative path for TitleBarIcon into absolute path
  $TitleBarIcon = (Get-Item -Path $TitleBarIcon).FullName

  # An app registration is needed to set the issuer name and icon in the title bar 
  Register-NotificationApplication -Id $Id -DisplayName $TitleBarHeader -IconPath $TitleBarIcon

  # When using system privileges, the block executes in a different context, 
  # so the relative path for LogoImage must be converted to an absolute path.
  # On another note, System.IO.FileInfo.FullName property isn't updated when you change your working directory in PowerShell, 
  # so in the case for user privileges, 
  # using Get-Item here to avoid getting wrong absolute path later 
  # when using System.IO.FileInfo.FullName property in New-HPPrivateToastNotificationLogo. 
  if ($LogoImage) {
    $LogoImage = (Get-Item -Path $LogoImage).FullName
  }

  $privs = whoami /priv /fo csv | ConvertFrom-Csv | Where-Object { $_. 'Privilege Name' -eq 'SeDelegateSessionUserImpersonatePrivilege' }
  if ($privs.State -eq "Disabled") {
    Write-Verbose "Running with user privileges"
    Invoke-HPPrivateRebootNotificationAsUser -Title $Title -Message $Message -LogoImage $LogoImage -Expiration $Expiration -Attribution $Id
  }
  else {
    Write-Verbose "Running with system privileges"
    
    try {
      $psPath = (Get-Process -Id $pid).Path
      # Passing the parameters as environment variable because the following block executes in a different context
      [System.Environment]::SetEnvironmentVariable('HPRebootTitle',$Title,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPRebootMessage',$Message,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPRebootAttribution',$Id,[System.EnvironmentVariableTarget]::Machine)

      if ($LogoImage) {
        [System.Environment]::SetEnvironmentVariable('HPRebootLogoImage',$LogoImage,[System.EnvironmentVariableTarget]::Machine)
      }
      if ($Expiration) {
        [System.Environment]::SetEnvironmentVariable('HPRebootExpiration',$Expiration,[System.EnvironmentVariableTarget]::Machine)
      }
   
      [scriptblock]$scriptBlock = {
        $path = $pwd.Path
        Import-Module -Force $path\HP.Notifications.psd1
        $params = @{
          Title = $env:HPRebootTitle
          Message = $env:HPRebootMessage
          Attribution = $env:HPRebootAttribution
        }

        if ($env:HPRebootLogoImage) {
          $params.LogoImage = $env:HPRebootLogoImage
        }
       
        if ($env:HPRebootExpiration) {
          $params.Expiration = $env:HPRebootExpiration
        }
      
        Invoke-HPPrivateRebootNotificationAsUser @params
      }

      $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptBlock))
      $psCommand = "-ExecutionPolicy Bypass -Window Normal -EncodedCommand $($encodedCommand)"
      [ProcessExtensions]::StartProcessAsCurrentUser($psPath,"`"$psPath`" $psCommand",$PSScriptRoot)
      [System.Environment]::SetEnvironmentVariable('HPRebootTitle',$null,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPRebootMessage',$null,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPRebootAttribution',$null,[System.EnvironmentVariableTarget]::Machine)

      if ($LogoImage) {
        [System.Environment]::SetEnvironmentVariable('HPRebootLogoImage',$null,[System.EnvironmentVariableTarget]::Machine)
      }
      if ($Expiration) {
        [System.Environment]::SetEnvironmentVariable('HPRebootExpiration',$null,[System.EnvironmentVariableTarget]::Machine)
      }
   
    }
    catch {
      Write-Error -Message "Could not execute as currently logged on user: $($_.Exception.Message)" -Exception $_.Exception
    }
  }

  # add a delay before unregistering the app because if you unregister the app right away, toast notification won't pop up 
  Start-Sleep -Seconds 5
  Unregister-NotificationApplication -Id $Id

  return
}


<#
.SYNOPSIS
  Triggers a toast notification from XML 

.DESCRIPTION
  This command triggers a toast notification from XML. Similar to the Invoke-HPNotification command, this command triggers toast notifications, but this command is more flexible and allows for more customization.

.PARAMETER Xml
  Specifies the schema XML content of the toast notification. Please specify either Xml or XmlPath, but not both.

.PARAMETER XmlPath
  Specifies the file path to the schema XML content of the toast notification. Please specify either Xml or XmlPath, but not both.

.PARAMETER ActionsJson
  Specifies the actions that should be map the button id(s) (if any specified in XML) to the command(s) to call upon clicking the corresponding button. You can specify either ActionsJson or ActionsJsonPath, but not both.

  Please note that button actions are registered in HKEY_CURRENT_USER in the registry. Button actions will persist until the user logs off. 

  Example to reboot the system upon clicking the button:
  [
   {
      "id":"rebootnow",
      "cmd":"C:\\Windows\\System32\\shutdown.exe -r -t 0 -f"
   }
  ]

.PARAMETER ActionsJsonPath
  Specifies the file path to the actions that should be map the button id(s) (if any specified in XML) to the command(s) to call upon clicking the corresponding button. You can specify either ActionsJson or ActionsJsonPath, but not both.
  
  Please note that button actions are registered in HKEY_CURRENT_USER in the registry. Button actions will persist until the user logs off. 

.PARAMETER Expiration
  Specifies the life of the toast notification in minutes whether toast notification is on the screen or in the Action Center. If not specified, the invoked toast notification remains on screen until dismissed.

.PARAMETER TitleBarHeader
  Specifies the text of the toast notification in the title bar. If not specified, the text will default to "HP System Notification". 

.PARAMETER TitleBarIcon
  Specifies the icon of the toast notification in the title bar. If not specified, the icon will default to the HP logo. Please note that the color of the icon might be inverted depending on the background color of the title bar.


.EXAMPLE
  Invoke-HPNotificationFromXML -XmlPath 'C:\path\to\schema.xml' -ActionsJsonPath 'C:\path\to\actions.json'

.EXAMPLE
  Invoke-HPNotificationFromXML -XmlPath 'C:\path\to\schema.xml' -ActionsJson '[
   {
      "id":"rebootnow",
      "cmd":"C:\\Windows\\System32\\shutdown.exe -r -t 0 -f"
   }
  ]'

.EXAMPLE
  Invoke-HPNotificationFromXML -XmlPath 'C:\path\to\schema.xml' 

#>
function Invoke-HPNotificationFromXML {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Invoke-HPNotificationFromXML")]
  param(
    [Parameter(ParameterSetName = 'XmlAJ',Mandatory = $false)]
    [Parameter(ParameterSetName = 'XmlAJP',Mandatory = $false)]
    [Parameter(ParameterSetName = 'XmlPathAJ',Mandatory = $false)]
    [Parameter(ParameterSetName = 'XmlPathAJP',Mandatory = $false)]
    [int]$Expiration = 0,

    [Parameter(ParameterSetName = 'XmlAJ',Mandatory = $false)]
    [Parameter(ParameterSetName = 'XmlAJP',Mandatory = $false)]
    [Parameter(ParameterSetName = 'XmlPathAJ',Mandatory = $false)]
    [Parameter(ParameterSetName = 'XmlPathAJP',Mandatory = $false)]
    [string]$TitleBarHeader = "HP System Notification", # we don't want to display "Windows PowerShell" in the title bar

    [Parameter(ParameterSetName = 'XmlAJ',Mandatory = $false)]
    [Parameter(ParameterSetName = 'XmlAJP',Mandatory = $false)]
    [Parameter(ParameterSetName = 'XmlPathAJ',Mandatory = $false)]
    [Parameter(ParameterSetName = 'XmlPathAJP',Mandatory = $false)]
    [System.IO.FileInfo]$TitleBarIcon = (Join-Path -Path $PSScriptRoot -ChildPath 'assets\hp_black_logo.png'), # default to HP logo
   
    [Parameter(ParameterSetName = 'XmlAJ',Mandatory = $true)]
    [Parameter(ParameterSetName = 'XmlAJP', Mandatory = $true)]
    [string]$Xml, # both $Xml and $XmlPath cannot be specified

    [Parameter(ParameterSetName = 'XmlPathAJ', Mandatory = $true)]
    [Parameter(ParameterSetName = 'XmlPathAJP', Mandatory = $true)]
    [System.IO.FileInfo]$XmlPath, # both $Xml and $XmlPath cannot be specified

    [Parameter(ParameterSetName = 'XmlAJ',Mandatory = $false)]
    [Parameter(ParameterSetName = 'XmlPathAJ',Mandatory = $false)]
    [string]$ActionsJson, # list of actions that should align with the buttons in the schema Xml file. If no buttons, this field is not needed

    # both $ActionsJson and $ActionsJsonPath cannot be specified, so making one mandatory to resolve ambiguity
    [Parameter(ParameterSetName = 'XmlAJP',Mandatory = $true)] 
    [Parameter(ParameterSetName = 'XmlPathAJP',Mandatory = $true)]
    [System.IO.FileInfo]$ActionsJsonPath 
    )

  # if Xml, save the contents to a file and set file path to $XmlPath
  if ($Xml) {
    # create a unique file name for the schema XML file to avoid conflicts
    $XmlPath = Join-Path -Path $PSScriptRoot -ChildPath "HPNotificationSchema$([DateTime]::Now.Ticks).xml"
    $Xml | Out-File -FilePath $XmlPath -Force
    Write-Verbose "Created schema XML file at $XmlPath"
  }

  # if ActionsJson, save the contents to a file and set file path to $ActionsJsonPath
  if ($ActionsJson) {
    # create a unique file name for the actions JSON file to avoid conflicts
    $ActionsJsonPath = Join-Path -Path $PSScriptRoot -ChildPath "HPNotificationActions$([DateTime]::Now.Ticks).json"
    $ActionsJson | Out-File -FilePath $ActionsJsonPath -Force
    Write-Verbose "Created actions JSON file at $ActionsJsonPath"
  }

  # Create a unique Id to distinguish this notification application from others using "hp.cmsl" and the current time
  $Id = "hp.cmsl.$([DateTime]::Now.Ticks)"

  # Convert the relative path for TitleBarIcon into absolute path
  $TitleBarIcon = (Get-Item -Path $TitleBarIcon).FullName

  # An app registration is needed to set the issuer name and icon in the title bar 
  Register-NotificationApplication -Id $Id -DisplayName $TitleBarHeader -IconPath $TitleBarIcon

  $privs = whoami /priv /fo csv | ConvertFrom-Csv | Where-Object { $_. 'Privilege Name' -eq 'SeDelegateSessionUserImpersonatePrivilege' }
  if ($privs.State -eq "Disabled") {
    Write-Verbose "Running with user privileges"
    Invoke-HPPrivateNotificationAsUser -Xml $XmlPath -Actions $ActionsJsonPath -Expiration $Expiration -Attribution $Id 
  }
  else {
    Write-Verbose "Running with system privileges"

    # XmlPath and ActionsJsonPath do not work with system privileges if a relative file path is passed in 
    # because the following block executes in a different context
    # If a relative path is passed in, convert the relative path into absolute path
    if ($XmlPath) {
      $XmlPath = (Get-Item -Path $XmlPath).FullName
    }

    if ($ActionsJsonPath) {
      $ActionsJsonPath = (Get-Item -Path $ActionsJsonPath).FullName
    }

    try {
      $psPath = (Get-Process -Id $pid).Path

      # Passing the parameters as environment variable because the following block executes in a different context
      [System.Environment]::SetEnvironmentVariable('HPNotificationFromXmlAttribution',$Id,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPNotificationFromXmlXml',$XmlPath,[System.EnvironmentVariableTarget]::Machine)
     
      if($ActionsJsonPath){
        [System.Environment]::SetEnvironmentVariable('HPNotificationFromXmlActions',$ActionsJsonPath,[System.EnvironmentVariableTarget]::Machine)
      }

      if ($Expiration) {
        [System.Environment]::SetEnvironmentVariable('HPNotificationFromXmlExpiration',$Expiration,[System.EnvironmentVariableTarget]::Machine)
      }

      [scriptblock]$scriptBlock = {
        $path = $pwd.Path
        Import-Module -Force $path\HP.Notifications.psd1
        $params = @{
          Xml = $env:HPNotificationFromXmlXml
          Actions = $env:HPNotificationFromXmlActions
          Attribution = $env:HPNotificationFromXmlAttribution
        }

        if ($env:HPNotificationFromXmlExpiration) {
          $params.Expiration = $env:HPNotificationFromXmlExpiration
        }

        Invoke-HPPrivateNotificationAsUser @params
      }

      $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptBlock))
      $psCommand = "-ExecutionPolicy Bypass -Window Normal -EncodedCommand $($encodedCommand)"
      [ProcessExtensions]::StartProcessAsCurrentUser($psPath,"`"$psPath`" $psCommand",$PSScriptRoot)

      [System.Environment]::SetEnvironmentVariable('HPNotificationFromXmlAttribution',$null,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPNotificationFromXmlXml',$null,[System.EnvironmentVariableTarget]::Machine)

      if($ActionsJsonPath){
        [System.Environment]::SetEnvironmentVariable('HPNotificationFromXmlActions',$null,[System.EnvironmentVariableTarget]::Machine)
      }
      if ($Expiration) {
        [System.Environment]::SetEnvironmentVariable('HPNotificationFromXmlExpiration',$null,[System.EnvironmentVariableTarget]::Machine)
      }
    }
    catch {
      Write-Error -Message "Could not execute as currently logged on user: $($_.Exception.Message)" -Exception $_.Exception
    }
  }

  # if temporary XML file was created, remove it
  if($Xml) {
    Remove-Item -Path $XmlPath -Force
    Write-Verbose "Removed temporary schema XML file at $XmlPath"
  }

  # if temporary Actions JSON file was created, remove it
  if($ActionsJson) {
    Remove-Item -Path $ActionsJsonPath -Force
    Write-Verbose "Removed temporary actions JSON file at $ActionsJsonPath"
  }

  # do not unregister the app because we want to allow the user to snooze the notification 
  return
}

<#
.SYNOPSIS
  Triggers a toast notification

.DESCRIPTION
  This command triggers a toast notification.

.PARAMETER Message
  Specifies the message to display. This parameter is mandatory. Please note, an empty string is not allowed.

.PARAMETER Title
  Specifies the title to display. This parameter is mandatory. Please note, an empty string is not allowed. 

.PARAMETER LogoImage
  Specifies the image file path to be displayed

.PARAMETER Expiration
  Specifies the life of the toast notification in minutes whether toast notification is on the screen or in the Action Center. If not specified, the invoked toast notification remains on screen until dismissed.

.PARAMETER TitleBarHeader
  Specifies the text of the toast notification in the title bar. If not specified, the text will default to "HP System Notification". 

.PARAMETER TitleBarIcon
  Specifies the icon of the toast notification in the title bar. If not specified, the icon will default to the HP logo. Please note that the color of the icon might be inverted depending on the background color of the title bar.

.PARAMETER Signature
  Specifies the text to display below the message at the bottom of the toast notification in a smaller font. Please note that on older versions of Windows that don't support attribution text, the signature will just be displayed as another text element in the same font as the message. 

.PARAMETER Dismiss
  If set to true or not specified, the toast notification will show a Dismiss button to dismiss the notification. If set to false, the toast notification will not show a Dismiss button and will disappear from the screen and go to the Action Center after 5-7 seconds of invocation. Please note that dismissing the notification overrides any specified Expiration time as the notification will not go to the Action Center once dismissed.


.EXAMPLE
  Invoke-HPNotification -Title "My title" -Message "My message" -Dismiss $false 

.EXAMPLE
  Invoke-HPNotificataion -Title "My title" -Message "My message" -Signature "Foo Bar" -Expiration 5
#>
function Invoke-HPNotification {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Invoke-HPNotification")]
  param(
    [Parameter(Position = 0,Mandatory = $true)]
    [string]$Title,

    [Parameter(Position = 1,Mandatory = $true)]
    [string]$Message,

    [Parameter(Position = 2,Mandatory = $false)]
    [System.IO.FileInfo]$LogoImage,

    [Parameter(Position = 3,Mandatory = $false)]
    [int]$Expiration = 0,

    [Parameter(Position = 4,Mandatory = $false)]
    [string]$TitleBarHeader = "HP System Notification", # we don't want to display "Windows PowerShell" in the title bar

    [Parameter(Position = 5,Mandatory = $false)]
    [System.IO.FileInfo]$TitleBarIcon = (Join-Path -Path $PSScriptRoot -ChildPath 'assets\hp_black_logo.png'), # default to HP logo

    [Parameter(Position = 6,Mandatory = $false)]
    [string]$Signature, # text in smaller font under Title and Message at the bottom of the toast notification 
    
    [Parameter(Position = 7,Mandatory = $false)]
    [bool]$Dismiss = $true # if not specified, default to showing the Dismiss button
  )

  # Create a unique Id to distinguish this notification application from others using "hp.cmsl" and the current time
  $Id = "hp.cmsl.$([DateTime]::Now.Ticks)"

  # Convert the relative path for TitleBarIcon into absolute path
  $TitleBarIcon = (Get-Item -Path $TitleBarIcon).FullName
  
  # An app registration is needed to set the issuer name and icon in the title bar 
  Register-NotificationApplication -Id $Id -DisplayName $TitleBarHeader -IconPath $TitleBarIcon

  # When using system privileges, the block executes in a different context, 
  # so the relative path for LogoImage must be converted to an absolute path.
  # On another note, System.IO.FileInfo.FullName property isn't updated when you change your working directory in PowerShell, 
  # so in the case for user privileges, 
  # using Get-Item here to avoid getting wrong absolute path later 
  # when using System.IO.FileInfo.FullName property in New-HPPrivateToastNotificationLogo. 
  if ($LogoImage) {
    $LogoImage = (Get-Item -Path $LogoImage).FullName
  }

  $privs = whoami /priv /fo csv | ConvertFrom-Csv | Where-Object { $_. 'Privilege Name' -eq 'SeDelegateSessionUserImpersonatePrivilege' }
  if ($privs.State -eq "Disabled") {
    Write-Verbose "Running with user privileges"

    # Invoke-HPPrivateNotificationAsUser is modeled after Invoke-HPPrivateRebootNotificationAsUser so using -NoDismiss instead of -Dismiss for consistency 
    if($Dismiss) {
      Invoke-HPPrivateNotificationAsUser -Title $Title -Message $Message -LogoImage $LogoImage -Expiration $Expiration -Attribution $Id -Signature $Signature -NoDismiss "false"
    }
    else {
      Invoke-HPPrivateNotificationAsUser -Title $Title -Message $Message -LogoImage $LogoImage -Expiration $Expiration -Attribution $Id -Signature $Signature -NoDismiss "true" 
    }
  }
  else {
    Write-Verbose "Running with system privileges"

    try {
      $psPath = (Get-Process -Id $pid).Path

      # Passing the parameters as environment variable because the following block executes in a different context
      [System.Environment]::SetEnvironmentVariable('HPNotificationTitle',$Title,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPNotificationMessage',$Message,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPNotificationSignature',$Signature,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPNotificationAttribution',$Id,[System.EnvironmentVariableTarget]::Machine)

      if ($LogoImage) {
        [System.Environment]::SetEnvironmentVariable('HPNotificationLogoImage',$LogoImage,[System.EnvironmentVariableTarget]::Machine)
      }
      if ($Expiration) {
        [System.Environment]::SetEnvironmentVariable('HPNotificationExpiration',$Expiration,[System.EnvironmentVariableTarget]::Machine)
      }

      # environment variables can only be strings, so we need to convert the Dismiss boolean to a string
      if($Dismiss) {
        [System.Environment]::SetEnvironmentVariable('HPNotificationNoDismiss', "false",[System.EnvironmentVariableTarget]::Machine)
      }
      else {
        [System.Environment]::SetEnvironmentVariable('HPNotificationNoDismiss', "true",[System.EnvironmentVariableTarget]::Machine)
      }
   
      [scriptblock]$scriptBlock = {
        $path = $pwd.Path
        Import-Module -Force $path\HP.Notifications.psd1
        $params = @{
          Title = $env:HPNotificationTitle
          Message = $env:HPNotificationMessage
          Signature = $env:HPNotificationSignature
          Attribution = $env:HPNotificationAttribution
          NoDismiss = $env:HPNotificationNoDismiss
        }

        if ($env:HPNotificationLogoImage) {
          $params.LogoImage = $env:HPNotificationLogoImage
        }
       
        if ($env:HPNotificationExpiration) {
          $params.Expiration = $env:HPNotificationExpiration
        }

        Invoke-HPPrivateNotificationAsUser @params
      }

      $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptBlock))
      $psCommand = "-ExecutionPolicy Bypass -Window Normal -EncodedCommand $($encodedCommand)"
      [ProcessExtensions]::StartProcessAsCurrentUser($psPath,"`"$psPath`" $psCommand",$PSScriptRoot)

      [System.Environment]::SetEnvironmentVariable('HPNotificationTitle',$null,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPNotificationMessage',$null,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPNotificationSignature',$null,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPNotificationAttribution',$null,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPNotificationNoDismiss',$null,[System.EnvironmentVariableTarget]::Machine)

      if ($LogoImage) {
        [System.Environment]::SetEnvironmentVariable('HPNotificationLogoImage',$null,[System.EnvironmentVariableTarget]::Machine)
      }
      if ($Expiration) {
        [System.Environment]::SetEnvironmentVariable('HPNotificationExpiration',$null,[System.EnvironmentVariableTarget]::Machine)
      }
    }
    catch {
      Write-Error -Message "Could not execute as currently logged on user: $($_.Exception.Message)" -Exception $_.Exception
    }
  }

  # add a delay before unregistering the app because if you unregister the app right away, toast notification won't pop up 
  Start-Sleep -Seconds 5
  Unregister-NotificationApplication -Id $Id

  return
}


# SIG # Begin signature block
# MIIoFwYJKoZIhvcNAQcCoIIoCDCCKAQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCATd9fabB8jbo8n
# vWMTBnTw/MRnfaz9Tn681PAHuGfycqCCDYowggawMIIEmKADAgECAhAIrUCyYNKc
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPrBUJGd
# Ck1MyAyspWRgzzUhWvdeosVA0rByE7Z57wwVMA0GCSqGSIb3DQEBAQUABIIBgC0s
# O5BgcybZ2F5OTF+sTEzqQpch6BQPIQUuxIwBmO8AV2fj29nBzEsbW2JY8/FaMrPZ
# iVtLtCUfTY9dpZsNRU/ia+lIiSbr5Y+solOocG0qqoGL91ciYMfb+R0yZgBM3FHZ
# xgWYcgczZing/kKkLGggzKSK2xAvNK+gi5XvtGrQGkmKLmo0h+bNPRjzlok90ivb
# dLizSnXJP1CnxlkODMrsWixplMe5B2TZa0tUZcDY5xNFMdMeb5RKMNlkcNc2soF1
# tSS+fKO634P5Rj6VKZVvQIQ+p9QE1ME0n5A0HP/wPp7f/VRSdXsQGco98x1rEHyb
# I3rYXCiNotoDlx8jZ+Tupxfg7EOuRtKjqAXusfCrEplq3SSQEJlEIGqxN1n6LPm2
# JmyjidkmDRkoy5/2OCbttSO1w5BRXELqCwL75c+oX6FKdLwIIfjjqrCfXHQ59sr7
# IFrH8MSmZcyy/PR8DnqQMpbu5D4WS8amyp6zd8vDFxnE1b7DQPfI0CSOGFGhQqGC
# Fzkwghc1BgorBgEEAYI3AwMBMYIXJTCCFyEGCSqGSIb3DQEHAqCCFxIwghcOAgED
# MQ8wDQYJYIZIAWUDBAIBBQAwdwYLKoZIhvcNAQkQAQSgaARmMGQCAQEGCWCGSAGG
# /WwHATAxMA0GCWCGSAFlAwQCAQUABCBpsGjuC2IbMVk0DFp/dJjB+1kWvfXkKUTy
# RoMqGRiKkwIQaJFRbP2SxPhOXi2rHqB+KRgPMjAyNTA0MTcxODQ4NTNaoIITAzCC
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
# EAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MTcxODQ4NTNaMCsGCyqGSIb3DQEJEAIM
# MRwwGjAYMBYEFNvThe5i29I+e+T2cUhQhyTVhltFMC8GCSqGSIb3DQEJBDEiBCCR
# HqfwZxc3CwAWPpJfis7gjVTpmXTJ6UMHCDlovJEASDA3BgsqhkiG9w0BCRACLzEo
# MCYwJDAiBCB2dp+o8mMvH0MLOiMwrtZWdf7Xc9sF1mW5BZOYQ4+a2zANBgkqhkiG
# 9w0BAQEFAASCAgBz8FxiLSfcHxaWiP+NVL0R/K/1bfH1P4acwsl5nyMA86AUfEfV
# Qwdp2FHf5KVgRAAWSnxhXZ680HDtUGhVmzfMTJEuaYcXYWI24AlQuN29oZ5KnuhV
# BTpSeinEgYxp/a/pLzlUbfGaVqbthc0Of8OS96v+IP/js0zJXJ/r9c5L6F3dHY5P
# 8eNv7d4faCwiVdmqNl5lI0xf/QG7aOx7pYCwfR+uo8XBvyX3Gnx/7ySjmaAc+5Jo
# NpWSHj2ycaMTQhohcy/MZ3oUUQJp1P9E2nfCD9pY86RlBnxc6a8x9kN5sy6BSOY/
# uX3ZjJUBFo+ICH0nRTtOgsN0Md2Qut7oMulrZDdUY7yeHcfQnidXTtPCYryC+tR+
# lgi9iUt5R9TcufnZFbVNWB0Y8+IoqwiU7pI78axTzn3lxGtdVYIXsjSFgsLJ5zpD
# H8ZwHciIpG9sfU91iZZXQ5qpAVpgCuQhnzyckDM4/KYBgOiqTpsINRSuFuTnFmAU
# W7qoMYCvObOWZQWx8iicApTvAnKPmypPhSKiFbf7xr16PgjSqBdjlR5e+r9S2eOT
# 7AQ24pNpnC36P2W7DUt1n+oKajHu6J76krtBbWB7ATy6olsgtE6L+b0MTne8ILBL
# 4YpfZBWPK04ZBUwYMr/9fwPi+XwwzkI36BQ4ys3JNu9oIIhhGzClUpjbcQ==
# SIG # End signature block
