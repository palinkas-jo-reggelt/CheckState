<#

.SYNOPSIS
	Test Windows Services

.DESCRIPTION
	Make sure Windows Services are running throughout the day

.FUNCTIONALITY
	1) Checks to see if service is running
	2) If not running, attempts to start
	3) If service doesn't start, then its run through a restart routine
	4) Sends notification messages by email and SMS

.NOTES
	Run every 5 minutes via task scheduler
	
.EXAMPLE

#>

<#  Include required files  #>
Try {
	.("$PSScriptRoot\CheckStatusConfig.ps1")
	.("$PSScriptRoot\CheckStatusFunctions.ps1")
}
Catch {
	Write-Output "$(Get-Date -f G) : ERROR : Unable to load supporting PowerShell Scripts : $query `n$($Error[0])" | Out-File "$PSScriptRoot\PSError.log" -Append
}

<#  First, check if machine recently rebooted  #>
If (PastBootup) {

	<#  Put array of services into foreach loop  #>
	ForEach ($ServiceName in $ServiceToCheck) {

		<#  Check if script should run during backup  #>
		If ($AvoidBackup) {
			<#  If not being called during backup period, then run it  #>
			If (($StartTime.TimeOfDay -le (Get-Date).TimeOfDay) -and ($EndTime.TimeOfDay -ge (Get-Date).TimeOfDay)) {
				TestService $ServiceName
			}

		<#  If script should run all the time, then just do it  #>
		} Else {
			TestService $ServiceName
		}
	}
}