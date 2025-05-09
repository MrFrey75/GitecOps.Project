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

# CMSL is normally installed in C:\Program Files\WindowsPowerShell\Modules
# but if installed via PSGallery and via PS7, it is installed in a different location
if (Test-Path "$PSScriptRoot\..\HP.Private\HP.CMSLHelper.dll") {
  Add-Type -Path "$PSScriptRoot\..\HP.Private\HP.CMSLHelper.dll"
}
else{
  Add-Type -Path "$PSScriptRoot\..\..\HP.Private\1.8.2\HP.CMSLHelper.dll"
}


enum LogType{
  Simple
  CMTrace
}

enum LogSeverity{
  Information = 1
  Warning = 2
  Error = 3
}

function Get-HPPrivateThreadID { [Threading.Thread]::CurrentThread.ManagedThreadId }
function Get-HPPrivateUserIdentity { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name }
function Get-HPPrivateLogVar { $Env:HPCMSL_LOG_FORMAT }

<#
.SYNOPSIS
  Sends a message to a syslog server

.DESCRIPTION
  This command forwards data to a syslog server. This command currently supports UDP (default) and TCP connections. For more information, see RFC 5424 in the 'See also' section.

.PARAMETER message
  Specifies the message to send

.PARAMETER severity
  Specifies the severity of the message. If not specified, the severity defaults to 'Informational'.

.PARAMETER facility
  Specifies the facility of the message. If not specified, the facility defaults to 'User Message'. 

.PARAMETER clientname
  Specifies the client name. If not specified, this command uses the current computer name.

.PARAMETER timestamp
  Specifies the event time stamp. If not specified, this command uses the current time.

.PARAMETER port
  Specifies the target port. If not specified and HPSINK_SYSLOG_MESSAGE_TARGET_PORT is not set, this command uses port 514 for both TCP and UDP.

.PARAMETER tcp
  If specified, this command uses TCP instead of UDP. Default is UDP. Switching to TCP may generate additional traffic but allows the protocol to acknowledge delivery.

.PARAMETER tcpframing
  Specifies octet-counting or non-transparent-framing TCP framing. This parameter only applies if the -tcp parameter is specified. Default value is octet-counting unless HPSINK_SYSLOG_MESSAGE_TCPFRAMING is specified. For more information, see RFC 6587 in the "See also" section.

.PARAMETER maxlen
  Specifies maximum length (in bytes) of message that the syslog server accepts. Common sizes are between 480 and 2048 bytes. Default is 2048 if not specified and HPSINK_SYSLOG_MESSAGE_MAXLEN is not set.

.PARAMETER target
  Specifies the target computer on which to perform this operation. Local computer is assumed if not specified and HPSINK_SYSLOG_MESSAGE_TARGET is not set.

.PARAMETER PassThru
  If specified, this command sends the message to the pipeline upon completion and any error in the command is non-terminating.


.NOTES

  This command supports the following environment variables. These overwrite the defaults documented above.

  - HPSINK_SYSLOG_MESSAGE_TARGET_PORT: override default target port
  - HPSINK_SYSLOG_MESSAGE_TCPFRAMING: override TCP Framing format
  - HPSINK_SYSLOG_MESSAGE_MAXLEN: override syslog message max length
  - HPSINK_SYSLOG_MESSAGE_TARGET: override host name of the syslog server


  Defaults can be configured via the environment. This affects all related commands. For example, when applying them to eventlog-related commands, all eventlog-related commands are affected.

  In the following example, the HPSINK_EVENTLOG_MESSAGE_TARGET and HPSINK_EVENTLOG_MESSAGE_SOURCE variables affect both the Register-EventLogSink and Send-ToEventLog commands.

  ```PowerShell
  $ENV:HPSINK_EVENTLOG_MESSAGE_TARGET="remotesyslog.mycompany.com"
  $ENV:HPSINK_EVENTLOG_MESSAGE_SOURCE="mysource"
  Register-EventLogSink
  "hello" | Send-ToEventLog
  ```


.INPUTS
  The message can be piped to this command, rather than provided via the -message parameter.

.OUTPUTS
  If the -PassThru parameter is specified, the original message is returned. This allows chaining multiple SendTo-XXX commands.

.EXAMPLE
   "hello" | Send-ToSyslog -tcp -server mysyslogserver.mycompany.com

   This sends "hello" to the syslog server on mysyslogserver.mycompany.com via TCP. Alternately, the syslog server could be set in the environment variable HPSINK_SYSLOG_MESSAGE_TARGET.

.LINK
    [RFC 5424 - "The Syslog Protocol"](https://tools.ietf.org/html/rfc5424)

.LINK
  [RFC 6587 - "Transmission of Syslog Messages over TCP"](https://tools.ietf.org/html/rfc6587)

.LINK
  [Send-ToEventlog](https://developers.hp.com/hp-client-management/doc/Send-ToEventLog)


#>
function Send-ToSyslog
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Send-ToSyslog")]
  param
  (
    [ValidateNotNullOrEmpty()][Parameter(Position = 0,ValueFromPipeline = $True,Mandatory = $True)] $message,
    [Parameter(Position = 1,Mandatory = $false)] [syslog_severity_t]$severity = [syslog_severity_t]::informational,
    [Parameter(Position = 2,Mandatory = $false)] [syslog_facility_t]$facility = [syslog_facility_t]::user_message,
    [Parameter(Position = 3,Mandatory = $false)] [string]$clientname,
    [Parameter(Position = 4,Mandatory = $false)] [string]$timestamp,
    [Parameter(Position = 5,Mandatory = $false)] [int]$port = $HPSINK:HPSINK_SYSLOG_MESSAGE_TARGET_PORT,
    [Parameter(Position = 6,Mandatory = $false)] [switch]$tcp,
    [ValidateSet("octet-counting","non-transparent-framing")][Parameter(Position = 7,Mandatory = $false)] [string]$tcpframing = $ENV:HPSINK_SYSLOG_MESSAGE_TCPFRAMING,
    [Parameter(Position = 8,Mandatory = $false)] [int]$maxlen = $ENV:HPSINK_SYSLOG_MESSAGE_MAXLEN,
    [Parameter(Position = 9,Mandatory = $false)] [switch]$PassThru,
    [Parameter(Position = 10,Mandatory = $false)] [string]$target = $ENV:HPSINK_SYSLOG_MESSAGE_TARGET
  )

  # Create a UDP Client Object
  $tcpclient = $null
  $use_tcp = $false


  #defaults (change these in environment)
  if ($target -eq $null -or $target -eq "") { throw "parameter $target is required" }
  if ($tcpframing -eq $null -or $tcpframing -eq "") { $tcpframing = "octet-counting" }
  if ($port -eq 0) { $port = 514 }
  if ($maxlen -eq 0) { $maxlen = 2048 }


  if ($tcp.IsPresent -eq $false) {
    switch ([int]$ENV:HPSINK_SYSLOG_MESSAGE_USE_TCP) {
      0 { $use_tcp = $false }
      1 { $use_tcp = $true }
    }
  }
  else { $use_tcp = $tcp.IsPresent }


  Write-Verbose "Sending message to syslog server"
  if ($use_tcp) {
    Write-Verbose "TCP Connection to $target`:$port"
    $client = New-Object System.Net.Sockets.TcpClient
  }
  else
  {
    Write-Verbose "UDP Connection to $target`:$port"
    $client = New-Object System.Net.Sockets.UdpClient
  }

  try {
    $client.Connect($target,$port)
  }
  catch {
    if ($_.Exception.innerException -ne $null) {
      Write-Error $_.Exception.innerException.Message -Category ConnectionError -ErrorAction Stop
    } else {
      Write-Error $_.Exception.Message -Category ConnectionError -ErrorAction Stop
    }
  }

  if ($use_tcp -and -not $client.Connected)
  {
    $prefix = "udp"
    if ($use_tcp) { $prefix = $tcp }
    throw "Could not connect to syslog host $prefix`://$target`:$port"
  }


  Write-Verbose "Syslog faciliy=$($facility.value__), severity=$($severity.value__)"

  $priority = ($facility.value__ * 8) + $severity.value__
  Write-Verbose "Priority is $priority"

  if (($clientname -eq "") -or ($clientname -eq $null)) {
    Write-Verbose "Defaulting to client = $($ENV:computername)"
    $clientname = $env:computername
  }

  if (($timestamp -eq "") -or ($timestamp -eq $null)) {
    $timestamp = Get-Date -Format "yyyy:MM:dd:-HH:mm:ss zzz"
    Write-Verbose "Defaulting to timestamp = $timestamp"
  }

  $msg = "<{0}>{1} {2} {3}" -f $priority,$timestamp,$hostname,$message

  Write-Verbose ("Sending the message: $msg")
  if ($use_tcp) {
    Write-Verbose ("Sending via TCP")


    if ($msg.Length -gt $maxlen) {
      $maxlen = $maxlen - ([string]$maxlen).Length
      Write-Verbose ("This message has been truncated because maximum effective length is $maxlen but the message is  $($msg.length) ")
      $msg = $msg.substring(0,$maxlen - ([string]$maxlen).Length)
    }

    switch ($tcpframing) {
      "octet-counting" {
        Write-Verbose "Encoding TCP payload with 'octet-counting'"
        $encoded = '{0} {1}' -f $msg.Length,$msg
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($encoded)
      }

      "non-transparent-framing" {
        Write-Verbose "Encoding with 'non-transparent-framing'"
        $encoded = '{0}{1}' -f $msg.Length,$msg
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($encoded)
      }
    }

    try {
      [void]$client.getStream().Write($bytes,0,$bytes.Length)
    }
    catch {
      throw ("Could not send syslog message: $($_.Exception.Message)")
    }
  }
  else
  {

    Write-Verbose ("Sending via UDP")
    try {
      $bytes = [System.Text.Encoding]::ASCII.GetBytes($msg)
      if ($bytes.Length -gt $maxlen) {
        Write-Verbose ("This message has been truncated, because maximum length is $maxlen but the message is  $($bytes.length) ")
        $bytes = $bytes[0..($maxlen - 1)]
      }
      [void]$client.Send($bytes,$bytes.Length)
    }
    catch {
      if (-not $PassThru.IsPresent) {
        throw ("Could not send syslog message: $($_.Exception.Message)")
      }
      else
      {
        Write-Error -Message $_.Exception.Message -ErrorAction Continue
      }

    }
  }

  Write-Verbose "Send complete"
  $client.Close();
  if ($PassThru) { return $message }
}


<#
.SYNOPSIS
  Registers a source in an event log

.DESCRIPTION
  This command registers a source in an event log. must be executed before sending messages to the event log via the Send-ToEventLog command. 
  The source must match the source in the Send-ToEventLog command. By default, it is assumed that the source is 'HP-CSL'.

  This command can be unregistered using the Unregister-EventLogSink command. 

.PARAMETER logname
  Specifies the log section in which to register this source

.PARAMETER source
  Specifies the event log source that will be used when logging.

  The source can also be specified via the HPSINK_EVENTLOG_MESSAGE_SOURCE environment variable.

.PARAMETER target
  Specifies the target computer on which to perform this command. Local computer is assumed if not specified, unless environment variable HPSINK_EVENTLOG_MESSAGE_TARGET is defined.

  Important: the user identity running the PowerShell script must have permissions to write to the remote event log.

.NOTES
  This command reads the following environment variables for setting defaults:

    - HPSINK_EVENTLOG_MESSAGE_SOURCE: override default source name
    - HPSINK_EVENTLOG_MESSAGE_LOG: override default message log name
    - HPSINK_EVENTLOG_MESSAGE_TARGET: override event log server name

.LINK
  [Unregister-EventLogSink](https://developers.hp.com/hp-client-management/doc/Unregister-EventLogSink)

.LINK
  [Send-ToEventLog](https://developers.hp.com/hp-client-management/doc/Send-ToEventLog)

.EXAMPLE
  Register-EventLogSink
#>
function Register-EventLogSink
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Register-EventLogSink")]
  param
  (
    [Parameter(Position = 0,Mandatory = $false)] [string]$logname = $ENV:HPSINK_EVENTLOG_MESSAGE_LOG,
    [Parameter(Position = 1,Mandatory = $false)] [string]$source = $ENV:HPSINK_EVENTLOG_MESSAGE_SOURCE,
    [Parameter(Position = 2,Mandatory = $false)] [string]$target = $ENV:HPSINK_EVENTLOG_MESSAGE_TARGET
  )


  #defaults (change these in environment)
  if ($source -eq $null -or $source -eq "") { $source = "HP-CSL" }
  if ($logname -eq $null -or $logname -eq "") { $logname = "Application" }
  if ($target -eq $null -or $target -eq "") { $target = "." }


  Write-Verbose "Registering source $logname / $source"
  $params = @{
    LogName = $logname
    source = $source
  }

  if ($target -ne ".") { $params.Add("ComputerName",$target) }
  New-EventLog @params
}

<#
.SYNOPSIS
   Unregisters a source registered by the Register-EventLogSink command 

.DESCRIPTION
  This command removes a registration that was previously registered by the Register-EventLogSink command. 

Note:
Switching between formats changes the file encoding. The 'Simple' mode uses unicode encoding (UTF-16) while the 'CMTrace' mode uses UTF-8. This is partly due to historical reasons
(default encoding in UTF1-16 and existing log is UTF-16) and partly due to limitations in CMTrace tool, which seems to have trouble with UTF-16 in some cases. 

As a result, it is important to start with a new log when switching modes. Writing UTF-8 to UTF-16 files or vice versa will cause encoding and display issues.  

.PARAMETER source  
  Specifies the event log source that was registered via the Register-EventLogSink command. The source can also be specified via the HPSINK_EVENTLOG_MESSAGE_SOURCE environment variable.

.PARAMETER target
  Specifies the target computer on which to perform this command. Local computer is assumed if not specified, unless environment variable
  HPSINK_EVENTLOG_MESSAGE_TARGET is defined.

  Important: the user identity running the PowerShell script must have permissions to write to the remote event log.

.NOTES
    This command reads the following environment variables for setting defaults:

  - HPSINK_EVENTLOG_MESSAGE_SOURCE: override default source name
  - HPSINK_EVENTLOG_MESSAGE_TARGET: override event log server name

.LINK
  [Register-EventLogSink](https://developers.hp.com/hp-client-management/doc/Register-EventLogSink)

.LINK
  [Send-ToEventLog](https://developers.hp.com/hp-client-management/doc/Send-ToEventLog)

.EXAMPLE
  Unregister-EventLogSink
#>
function Unregister-EventLogSink
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Unregister-EventLogSink")]
  param
  (
    [Parameter(Position = 0,Mandatory = $false)] [string]$source = $ENV:HPSINK_EVENTLOG_MESSAGE_SOURCE,
    [Parameter(Position = 1,Mandatory = $false)] [string]$target = $ENV:HPSINK_EVENTLOG_MESSAGE_TARGET
  )

  #defaults (change these in environment)
  if ($source -eq $null -or $source -eq "") { $source = "HP-CSL" }
  if ($target -eq $null -or $target -eq "") { $target = "." }


  Write-Verbose "Unregistering source $source"
  $params = @{
    source = $source
  }

  if ($target -ne ".") { $params.Add("ComputerName",$target) }
  Remove-EventLog @params
}

<#
.SYNOPSIS
  Sends a message to an event log

.DESCRIPTION
  This command sends a message to an event log. 

  The source should be initialized with the Register-EventLogSink command to register the source name prior to using this command. 

.PARAMETER id
  Specifies the event id that will be registered under the 'Event ID' column in the event log. Default value is 0. 

.PARAMETER source
  Specifies the event log source that will be used when logging. This source should be registered via the Register-EventLogSink command. 

  The source can also be specified via the HPSINK_EVENTLOG_MESSAGE_SOURCE environment variable.

.PARAMETER message
  Specifies the message to log. This parameter is required.

.PARAMETER severity
  Specifies the severity of the message. If not specified, the severity is set as 'Information'.

.PARAMETER category
  Specifies the category of the message. The category shows up under the 'Task Category' column. If not specified, it is 'General', unless environment variable HPSINK_EVENTLOG_MESSAGE_CATEGORY is defined.

.PARAMETER logname
  Specifies the log in which to log (e.g. Application, System, etc). If not specified, it will log to Application, unless environment variable HPSINK_EVENTLOG_MESSAGE_LOG is defined.

.PARAMETER rawdata
  Specifies any raw data to add to the log entry 

.PARAMETER target
  Specifies the target computer on which to perform this operation. Local computer is assumed if not specified, unless environment variable HPSINK_EVENTLOG_MESSAGE_TARGET is defined.

  Important: the user identity running the PowerShell script must have permissions to write to the remote event log.

.PARAMETER PassThru
  If specified, this command sends the message to the pipeline upon completion and any error in the command is non-terminating.

.EXAMPLE 
    "hello" | Send-ToEventLog 

.NOTES
    This command reads the following environment variables for setting defaults.

  - HPSINK_EVENTLOG_MESSAGE_SOURCE: override default source name
  - HPSINK_EVENTLOG_MESSAGE_CATEGORY: override default category id
  - HPSINK_EVENTLOG_MESSAGE_LOG: override default message log name
  - HPSINK_EVENTLOG_MESSAGE_TARGET: override event log server name

  Defaults can be configured via the environment. This affects all related commands. For example, when applying them to eventlog-related commands, all eventlog-related commands are affected.

  In the following example, the HPSINK_EVENTLOG_MESSAGE_TARGET and HPSINK_EVENTLOG_MESSAGE_SOURCE variables affect both the Register-EventLogSink and Send-ToEventLog commands.

  ```PowerShell
  $ENV:HPSINK_EVENTLOG_MESSAGE_TARGET="remotesyslog.mycompany.com"
  $ENV:HPSINK_EVENTLOG_MESSAGE_SOURCE="mysource"
  Register-EventLogSink
  "hello" | Send-ToEventLog
  ```


.LINK
  [Unregister-EventLogSink](https://developers.hp.com/hp-client-management/doc/Unregister-EventLogSink)

.LINK
  [Register-EventLogSink](https://developers.hp.com/hp-client-management/doc/Register-EventLogSink)

.LINK
  [Send-ToSyslog](https://developers.hp.com/hp-client-management/doc/Send-ToSyslog)


#>
function Send-ToEventLog
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Send-ToEventlog")]
  param
  (

    [Parameter(Position = 0,Mandatory = $false)] [string]$source = $ENV:HPSINK_EVENTLOG_MESSAGE_SOURCE,
    [Parameter(Position = 1,Mandatory = $false)] [int]$id = 0,
    [ValidateNotNullOrEmpty()][Parameter(Position = 2,ValueFromPipeline = $true,Mandatory = $True)] $message,
    [Parameter(Position = 3,Mandatory = $false)] [eventlog_severity_t]$severity = [eventlog_severity_t]::informational,
    [Parameter(Position = 4,Mandatory = $false)] [int16]$category = $ENV:HPSINK_EVENTLOG_MESSAGE_CATEGORY,
    [Parameter(Position = 5,Mandatory = $false)] [string]$logname = $ENV:HPSINK_EVENTLOG_MESSAGE_LOG,
    [Parameter(Position = 6,Mandatory = $false)] [byte[]]$rawdata = $null,
    [Parameter(Position = 7,Mandatory = $false)] [string]$target = $ENV:HPSINK_EVENTLOG_MESSAGE_TARGET,
    [Parameter(Position = 8,Mandatory = $false)] [switch]$PassThru
  )

  #defaults (change these in environment)
  if ($source -eq $null -or $source -eq "") { $source = "HP-CSL" }
  if ($logname -eq $null -or $logname -eq "") { $logname = "Application" }
  if ($target -eq $null -or $target -eq "") { $target = "." }

  Write-Verbose "Sending message (category=$category, id=$id) to eventlog $logname with source $source"
  $params = @{
    EntryType = $severity.value__
    Category = $category
    Message = $message
    LogName = $logname
    source = $source
    EventId = $id
  }


  if ($target -ne ".") {
    $params.Add("ComputerName",$target)
    Write-Verbose ("The target machine is remote ($target)")
  }

  if ($rawdata -ne $null) { $params.Add("RawData",$rawdata) }

  try {
    Write-EventLog @params
  }
  catch {
    if (-not $PassThru.IsPresent) {
      throw ("Could not send eventlog message: $($_.Exception.Message)")
    }
    else
    {
      Write-Error -Message $_.Exception.Message -ErrorAction Continue
    }
  }
  if ($PassThru) { return $message }
}




<#
.SYNOPSIS
   Writes a 'simple' LOG entry
   Private command. Do not export
#>
function Write-HPPrivateSimple {

  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $True,Position = 0)]
    [LogSeverity]$Severity,
    [Parameter(Mandatory = $True,Position = 1)]
    [string]$Message,
    [Parameter(Mandatory = $True,Position = 2)]
    [string]$Component,
    [Parameter(Mandatory = $False,Position = 3)]
    [string]$File = $Null
  )
  $prefix = switch ($severity) {
    Error { " [ERROR] " }
    Warning { " [WARN ] " }
    default { "" }
  }

  if ($File) {
    if (-not [System.IO.Directory]::Exists([System.IO.Path]::GetDirectoryName($File)))
    {
      throw [System.IO.DirectoryNotFoundException]"Path not found: $([System.IO.Path]::GetDirectoryName($File))"
    }
  }

  $context = Get-HPPrivateUserIdentity

  $line = "[$(Get-Date -Format o)] $Context  - $Prefix $Message"
  if ($File) {
    $line | Out-File -Width 1024 -Append -Encoding unicode -FilePath $File
  }
  else {
    $line
  }

}

<#
.SYNOPSIS
   Writes a 'CMTrace' LOG entry
   Private command. Do not export
#>
function Write-HPPrivateCMTrace {
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $True,Position = 0)]
    [LogSeverity]$Severity,
    [Parameter(Mandatory = $True,Position = 1)]
    [string]$Message,
    [Parameter(Mandatory = $True,Position = 2)]
    [string]$Component,
    [Parameter(Mandatory = $False,Position = 3)]
    [string]$File

  )

  $line = "<![LOG[$Message]LOG]!>" + `
     "<time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" " + `
     "date=`"$(Get-Date -Format "M-d-yyyy")`" " + `
     "component=`"$Component`" " + `
     "context=`"$(Get-HPPrivateUserIdentity)`" " + `
     "type=`"$([int]$Severity)`" " + `
     "thread=`"$(Get-HPPrivateThreadID)`" " + `
     "file=`"`">"

  if ($File) {
    if (-not [System.IO.Directory]::Exists([System.IO.Path]::GetDirectoryName($File)))
    {
      throw [System.IO.DirectoryNotFoundException]"Path not found: $([System.IO.Path]::GetDirectoryName($File))"
    }
  }

  if ($File) {
    $line | Out-File -Append -Encoding UTF8 -FilePath $File -Width 1024
  }
  else {
    $line
  }

}




<#
.SYNOPSIS
  Sets the format used by the Write-Log* commands 

.DESCRIPTION
  This command sets the log format used by the Write-Log* commands. The two formats supported are simple (human readable) format and CMtrace format used by configuration manager.

  The format is stored in the HPCMSL_LOG_FORMAT environment variable. To set the default format without using this command, update the variable by setting it to either 'Simple' or 'CMTrace' ahead of time.

  The default format is 'Simple'. 

.PARAMETER Format
  Specifies the log format. The value must be one of the following values:
  - Simple: human readable
  - CMTrace: XML format used by the CMTrace tool

.EXAMPLE
  Set-HPCMSLLogFormat -Format CMTrace

.LINK
  [Write-LogInfo](https://developers.hp.com/hp-client-management/doc/Write-LogInfo)

.LINK
  [Write-LogWarning](https://developers.hp.com/hp-client-management/doc/Write-LogWarning)

.LINK
  [Write-LogError](https://developers.hp.com/hp-client-management/doc/Write-LogError)

.LINK
  [Get-HPCMSLLogFormat](https://developers.hp.com/hp-client-management/doc/Get-HPCMSLLogFormat)

#>
function Set-HPCMSLLogFormat
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Set-HPCMSLLogFormat")]
  param(
    [Parameter(Mandatory = $True,Position = 0)]
    [LogType]$Format
  )
  $Env:HPCMSL_LOG_FORMAT = $Format
  $Global:CmslLog = $Global:CmslLogType

  Write-Debug "Set log type to $($Global:CmslLog)"
}

<#
.SYNOPSIS
  Retrieves the format used by the log commands
  
.DESCRIPTION
  This command retrieves the configured log format used by the Write-Log* commands. This command returns the value of the HPCMSL_LOG_FORMAT environment variable or 'Simple' if the variable is not configured.

.PARAMETER Format
  Specifies the log format. The value must be one of the following values:
  - Simple: human readable
  - CMTrace: XML format used by the CMTrace tool

.EXAMPLE
  Get-HPCMSLLogFormat -Format CMTrace

.LINK
  [Write-LogInfo](https://developers.hp.com/hp-client-management/doc/Write-LogInfo)
.LINK
  [Write-LogWarning](https://developers.hp.com/hp-client-management/doc/Write-LogWarning)
.LINK  
  [Write-LogError](https://developers.hp.com/hp-client-management/doc/Write-LogError)
.LINK  
  [Set-HPCMSLLogFormat](https://developers.hp.com/hp-client-management/doc/Set-HPCMSLLogFormat)

#>
function Get-HPCMSLLogFormat
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get-HPCMSLLogFormat")]
  param()

  if (-not $Global::CmslLog)
  {
    $Global:CmslLog = Get-HPPrivateLogVar
  }

  if (-not $Global:CmslLog)
  {
    $Global:CmslLog = 'Simple'
  }

  Write-Verbose "Configured log type is $($Global:CmslLog)"

  switch ($Global:CmslLog)
  {
    'CMTrace' { 'CMTrace' }
    Default { 'Simple' }
  }

}


<#
.SYNOPSIS
  Writes a 'warning' log entry
  
.DESCRIPTION
  This command writes a 'warning' log entry to default output or a specified file.

.PARAMETER Message
  Specifies the message to write

.PARAMETER Component
  Specifies a 'Component' tag for the message entry. Some log readers use this parameter to group messages. If not specified, the component tag is 'General'.
  This parameter is ignored in 'Simple' mode due to backwards compatibility reasons.

.PARAMETER File
  Specifies the file to update with the new log entry. If not specified, the log entry is written to the pipeline.

.EXAMPLE
  Write-LogWarning -Component "Repository" -Message "Something bad may have happened" -File myfile.log

.LINK
  [Write-LogInfo](https://developers.hp.com/hp-client-management/doc/Write-LogInfo)
.LINK  
  [Write-LogError](https://developers.hp.com/hp-client-management/doc/Write-LogError)
.LINK  
  [Get-HPCMSLLogFormat](https://developers.hp.com/hp-client-management/doc/Get-HPCMSLLogFormat)
.LINK  
  [Set-HPCMSLLogFormat](https://developers.hp.com/hp-client-management/doc/Set-HPCMSLLogFormat)

#>
function Write-LogWarning
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Write-LogWarning")]
  param(
    [Parameter(Mandatory = $True,Position = 0)]
    [string]$Message,
    [Parameter(Mandatory = $False,Position = 1)]
    [string]$Component = "General",
    [Parameter(Mandatory = $False,Position = 2)]
    [string]$File
  )
  if ($File) {
    $file = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file)
  }
  switch (Get-HPCMSLLogFormat)
  {
    CMTrace {
      Write-HPPrivateCMTrace -Severity Warning -Message $Message -Component $Component -File $File
    }
    default {
      Write-HPPrivateSimple -Severity Warning -Message $Message -Component $Component -File $file
    }
  }


}


<#
.SYNOPSIS
  Writes an 'error' log entry
  
.DESCRIPTION
  This command writes an 'error' log entry to default output or a specified file.

.PARAMETER Message
  Specifies the message to write

.PARAMETER Component
  Specifies a 'Component' tag for the message entry. Some log readers use this parameter to group messages. If not specified, the component tag is 'General'.
  This parameter is ignored in 'Simple' mode due to backwards compatibility reasons.

.PARAMETER File
  Specifies the file to update with the new log entry. If not specified, the log entry is written to pipeline.

.EXAMPLE
  Write-LogError -Component "Repository" -Message "Something bad happened" -File myfile.log

.LINK
  [Write-LogInfo](https://developers.hp.com/hp-client-management/doc/Write-LogInfo)
.LINK  
  [Write-LogWarning](https://developers.hp.com/hp-client-management/doc/Write-LogWarning)
.LINK  
  [Get-HPCMSLLogFormat](https://developers.hp.com/hp-client-management/doc/Get-HPCMSLLogFormat)
.LINK  
  [Set-HPCMSLLogFormat](https://developers.hp.com/hp-client-management/doc/Set-HPCMSLLogFormat)
  
#>
function Write-LogError
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Write-LogError")]
  param(
    [Parameter(Mandatory = $True,Position = 0)]
    [string]$Message,
    [Parameter(Mandatory = $False,Position = 1)]
    [string]$Component = "General",
    [Parameter(Mandatory = $False,Position = 2)]
    [string]$File
  )

  if ($File) {
    $file = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file)
  }
  switch (Get-HPCMSLLogFormat)
  {
    CMTrace {
      Write-HPPrivateCMTrace -Severity Error -Message $Message -Component $Component -File $file
    }
    default {
      Write-HPPrivateSimple -Severity Error -Message $Message -Component $Component -File $file
    }
  }

}

<#
.SYNOPSIS
  Writes an 'informational' log entry
  
.DESCRIPTION
  This command writes an 'informational' log entry to default output or a specified file.

.PARAMETER Message
  Specifies the message to write

.PARAMETER Component
  Specifies a 'Component' tag for the message entry. Some log readers use this parameter to group messages. If not specified, the component tag is 'General'.
  This parameter is ignored in 'Simple' mode due to backwards compatibility reasons.

.PARAMETER File
  Specifies the file to update with the new log entry. If not specified, the log entry is written to pipeline.

.EXAMPLE
  Write-LogInfo -Component "Repository" -Message "Nothing bad happened" -File myfile.log
#>
function Write-LogInfo
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Write-LogInfo")]
  param(
    [Parameter(Mandatory = $True,Position = 0)]
    [string]$Message,
    [Parameter(Mandatory = $False,Position = 1)]
    [string]$Component = "General",
    [Parameter(Mandatory = $False,Position = 2)]
    [string]$File
  )
  if ($File) {
    $file = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file)
  }

  switch (Get-HPCMSLLogFormat)
  {
    CMTrace {
      Write-HPPrivateCMTrace -Severity Information -Message $Message -Component $Component -File $file
    }
    default {
      Write-HPPrivateSimple -Severity Information -Message $Message -Component $Component -File $file
    }
  }

}

# SIG # Begin signature block
# MIIoFwYJKoZIhvcNAQcCoIIoCDCCKAQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDXAswIPHAb/SOB
# ipKdkgE2WZ6YdITo/ZQxXAZ/mnqeYqCCDYowggawMIIEmKADAgECAhAIrUCyYNKc
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIFCsyzRU
# iyV5DXeYhg/+FBZMIptqMYn23ENEkUkPA8xHMA0GCSqGSIb3DQEBAQUABIIBgEqR
# JHuz0HA2wOaaHraJ/CSfXTI2GleJi3+jvdXGCCS+zmzz8fjR8QQYR9MCLtJI5BM7
# 4zP85LrIsTL15YC80i7jCYJloaCUiQRdx1bHGSGguGjyFilxvi9p4RZd5XBmLzKr
# FQuzPlBYyU23bFpd+91mAyj9eUUX55lbgtcwc1ndnsRQe0aj+HDWoeRlBomiDyRG
# mLAEFrhun68EKwsvwNDdUCLx/tlJwXREXbyh4lrFTHlJs05fAwATVMW/BczbS9S/
# gYtPbd8mFWMhe7qAiY98kJnoVm/Xd3BtOA9BSpvy++rwA1oZRPV8q5s0hG/I+b2M
# ZliiTqyDrWTutsEyKFbViq8mfmmu63ZLsX4x3EO1H1weSQfDqJUeOnqrOHMJKhap
# wvpY4I/ObA2riMR2smxyYfAL+aDxV138D/CvBsIahZFQoE3KfikG8OwkCINfnMfT
# Q3jmFs87Q+hvIxb5hRePkRkNSArtwQC791+IctJ/0/0Id0r5GHbp3bk8rdGt5KGC
# Fzkwghc1BgorBgEEAYI3AwMBMYIXJTCCFyEGCSqGSIb3DQEHAqCCFxIwghcOAgED
# MQ8wDQYJYIZIAWUDBAIBBQAwdwYLKoZIhvcNAQkQAQSgaARmMGQCAQEGCWCGSAGG
# /WwHATAxMA0GCWCGSAFlAwQCAQUABCDb+zW8zhvUCG0LCUkf340izEpOsBeqqiN7
# y9GVjCobvwIQVEQ6bgROehH7J0K00djozhgPMjAyNTA0MTcxODQ4NTBaoIITAzCC
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
# EAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MTcxODQ4NTBaMCsGCyqGSIb3DQEJEAIM
# MRwwGjAYMBYEFNvThe5i29I+e+T2cUhQhyTVhltFMC8GCSqGSIb3DQEJBDEiBCBn
# perYXjLBBPZeyP8gKDeqsGaWErD2BGCK/UMXmK7xbDA3BgsqhkiG9w0BCRACLzEo
# MCYwJDAiBCB2dp+o8mMvH0MLOiMwrtZWdf7Xc9sF1mW5BZOYQ4+a2zANBgkqhkiG
# 9w0BAQEFAASCAgAX26MctVHChmjcT59F+IrhwwxDTBeoCaHOvYpVoIQdSvRrllG9
# rZFiQz47UYu+l0Yq1F0Ez3smwWNF+8Cci2wlgQYiPWEJu41p6y+bssigIqlJQIdD
# bF7a8J4CeIj20eT8SfxzKV/BFkH3r9gINVQzzmxnj7JszpoVXt5OSiEScIt3C7Xq
# wzhZ132ZILuOMUQjOU/V6EaMxPQIgQ0MDFmzweMET7HLAAr3Nq+kAGh6QgTeXj0K
# qdGSR4rLqfCo+AuSXUvxg6xurMjYUowo1EWBbvNkOtkYJcDCc0ab4xHBH2J8llnp
# CkBgA3M9rd4lkKsRiAXSB3janaXGfGZhwDjcdgsaM5m3wNLypRwFl6VR0WRIPTwC
# IgNoogfYsvAOf59+93P+QhaImQV/XcsReMXnbmqw83hhocYVc7thlch7JN1wZN4f
# 0x5I/6e9/Dg5fhoFOKsRxOOL5o4W/01tcAyclz25l2kPFnN/Z+GZSHZxfcAnEky5
# FPNstXZcJl9UoaFlXkNuphpVKZzuwVkzuIG7RiERyE+5BOvkfizHrEpcDvD4B/Iy
# QvR8BF5AZVQYG+OFI4q/YxhQEMwD3tfazHYki0BAkVmyZAuQscqKbv6+Mi/YB2x0
# xeLo/xDwEj3SJtRn1uXgjhp4egoQnwxyT0K7SQ5MCAfDc8iW79NY88VY8w==
# SIG # End signature block
