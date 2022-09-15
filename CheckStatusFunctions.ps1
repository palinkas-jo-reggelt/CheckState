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

Function Debug ($DebugOutput) {
	Write-Output "$(Get-Date -f G) : $DebugOutput" | Out-File "$PSScriptRoot\$((Get-Date).ToString('yyyy-MM-dd'))-Debug.log" -Encoding ASCII -Append
}

Function Notify($Body) {
	If ($UseEmail){
		Try {
			Email $Body
		}
		Catch {
			Debug "Email Error: $($Error[0])"
		}
	}
	If ($UseSMS){
		Try {
			SMS $Body
		}
		Catch {
			Debug "SMS   Error: $($Error[0])"
		}
	}
}

Function Email($Body) {
	If (Test-Path $FileAttachment){$Attachment = New-Object System.Net.Mail.Attachment $FileAttachment}
	$Message = New-Object System.Net.Mail.Mailmessage $FromAddress, $Recipient, $Subject, $Body
	$Message.IsBodyHTML = [System.Convert]::ToBoolean($HTML)
	If (Test-Path $FileAttachment){$Message.Attachments.Add($FileAttachment)}
	$SMTP = New-Object System.Net.Mail.SMTPClient $SMTPServer,$SMTPPort
	$SMTP.EnableSsl = [System.Convert]::ToBoolean($SSL)
	$SMTP.Credentials = New-Object System.Net.NetworkCredential($SMTPAuthUser, $SMTPAuthPass); 
	$SMTP.Send($Message)
}

Function SMS($Msg) {
	& C:\scripts\Twilio\TwilioSend.ps1 -Num $SMSTo -Msg $Msg
}

Function PastBootup {
	$OKToProceed = $False
	$MinutesSinceBoot = [int](New-Timespan ([DateTime]::ParseExact((((Get-WmiObject -Class win32_operatingsystem).LastBootUpTime).Split(".")[0]), 'yyyyMMddHHmmss', $null))).TotalMinutes
	If ($MinutesSinceBoot -gt $AvoidRecentBoot) {$OKToProceed = $True}

	Return $OKToProceed
}

Function TestService($ServiceName) {
	If ((Get-Service $ServiceName).Status -ne 'Running'){
		$NotifyMsg = "ATTENTION! $ServiceName found to be not running. Attempting restart."
		Notify $NotifyMsg
		Start-Service $ServiceName
		Start-Sleep -seconds 60

		<#  If still not running, send through restart routine  #>
		(Get-Service $ServiceName).Refresh()
		If ((Get-Service $ServiceName).Status -ne 'Running'){
			RestartRoutine $ServiceName
		} Else {
			$NotifyMsg = "$ServiceName successfully restarted."
			Notify $NotifyMsg
		}
	}
}

Function RestartRoutine($ServiceName) {
	<#  Send notification, then restart service  #>
	$NotifyMsg = "ATTENTION! $ServiceName service is being RESTARTED due to a fault. Check status NOW!" 
	Notify $NotifyMsg

	<#  Shutdown Routine  #>
	$BeginShutdown = Get-Date
	Do {
		Stop-Service $ServiceName
		Start-Sleep -Seconds 60
		(Get-Service $ServiceName).Refresh()
		$ServiceStatus = (Get-Service $ServiceName).Status
	} Until (((New-Timespan -Start $BeginShutdown -End (Get-Date)).Minutes -gt $Timeout) -or ($ServiceStatus -eq "Stopped"))

	If ($ServiceStatus -ne "Stopped"){
		$NotifyMsg = "$ServiceName could not be stopped during restart process. Check status NOW."
		Notify $NotifyMsg
		Exit
	}

	<#  Startup Routine  #>
	$BeginStartup = Get-Date
	Do {
		Start-Service $ServiceName
		Start-Sleep -seconds 60
		(Get-Service $ServiceName).Refresh()
		$ServiceStatus = (Get-Service $ServiceName).Status
	} Until (((New-Timespan -Start $BeginStartup -End (Get-Date)).Minutes -gt $Timeout) -or ($ServiceStatus -eq "Running"))

	If ($ServiceStatus -ne "Running"){
		$NotifyMsg = "$ServiceName could not be started during restart process. Check status NOW."
		Notify $NotifyMsg
		Exit
	}
}