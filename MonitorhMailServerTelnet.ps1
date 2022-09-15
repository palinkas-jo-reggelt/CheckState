<#

.SYNOPSIS
	Test telnet on hMailServer

.DESCRIPTION
	Uses telnet to ensure hMailServer properly functioning

.FUNCTIONALITY
	1) Telnets in to hMailServer and checks for 220 Banner
	2) If banner found, exit
	3) If banner not found then wait, check again, if still not found then restart hMailServer service
	4) Sends notification messages by email and SMS

.NOTES
	Run every 5 minutes via task scheduler
	
.EXAMPLE

#>

<###   SCRIPT VARIABLES   ###>
$Banner       = 'wap.dynu.net'                         # hMailServer smtp banner
$ServiceName  = 'hMailServer'                          # name of hMailServer service (installation default is 'hMailServer')
$StreamFile   = "$PSScriptRoot\telnetout.txt"          # location of test output (temporary file)
$Timeout      = 5                                      # number of minutes to try service shutdown or startup before giving up

<#  Include required files  #>
Try {
	.("$PSScriptRoot\CheckStatusConfig.ps1")
	.("$PSScriptRoot\CheckStatusFunctions.ps1")
}
Catch {
	Write-Output "$(Get-Date -f G) : ERROR : Unable to load supporting PowerShell Scripts : $query `n$($Error[0])" | Out-File "$PSScriptRoot\PSError.log" -Append
}

<###   FUNCTIONS   ###>

Function CkTelnet {
	$Socket = New-Object System.Net.Sockets.TcpClient('localhost', 25)
	If ($Socket)
	{	$Stream = $Socket.GetStream()
		$Writer = New-Object System.IO.StreamWriter($Stream)
		$Buffer = New-Object System.Byte[] 1024
		$Encoding = New-Object System.Text.AsciiEncoding
	ForEach ($Command in $Commands)
		{ $Writer.WriteLine($Command)
		  $Writer.Flush()
		}
	}   
	Start-Sleep -seconds (2)
	$Result = ""
	While($Stream.DataAvailable)
	{	$Read = $Stream.Read($Buffer, 0, 1024)
		$Result += ($Encoding.GetString($Buffer, 0, $Read)) | Out-File $StreamFile 
	}
}

Function SecondTry {
	<#  Send notification, then wait 60 seconds and try telnet again  #>
	$NotifyMsg = "ATTENTION! hMailServer is NOT RESPONDING to telnet commands. Check status NOW."
	Notify $NotifyMsg
	Start-Sleep -seconds 60
	<#  Test telnet connection, if success then exit, if failure then restart service  #>
	CkTelnet
	If (Test-Path $StreamFile){
		$TestResult = Get-Content $StreamFile | Out-String
		Remove-Item -Path $StreamFile
		If ($TestResult -match $Banner){Exit}
		Else {RestartRoutine "hMailServer"}
	}
	Else {RestartRoutine "hMailServer"}
}

Function TryTelnet {
	<#  Test telnet connection, if success then exit, if failure then wait 1 minute and try again  #>
	CkTelnet
	If (Test-Path $StreamFile){
		$TestResult = Get-Content $StreamFile | Out-String
		Remove-Item -Path $StreamFile
		If ($TestResult -match $Banner){Exit}
		Else {SecondTry}
	}
	Else {SecondTry}
}

<###   START SCRIPT   ###>

<#  Check if script should run during backup  #>
If ($AvoidBackup){
	<#  If not being called during backup period, then run it  #>
	If (($StartTime.TimeOfDay -le (Get-Date).TimeOfDay) -and ($EndTime.TimeOfDay -ge (Get-Date).TimeOfDay)) {
		TryTelnet
	}
<#  If script should run all the time, then just do it  #>
} Else {
	TryTelnet
}