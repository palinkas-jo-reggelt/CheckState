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

###   SCRIPT VARIABLES   ###
$AvoidBackup      = $True                # if true, script will not run during backup routine in case hMailServer is shut down during backup
$StartTime        = Get-Date '02:00'     # run script start time - sometime after nightly backup ends
$EndTime          = Get-Date '23:45'     # run script end time - sometime before nightly backup begins
$AvoidRecentBoot  = 10                   # number of minutes after reboot that script will not run (give time for services to fully startup and run)
$Timeout          = 3                    # number of minutes to try service shutdown or startup before giving up

###   SERVICES TO CHECK   ###
$ServiceToCheck = @(                     # array of services to check - check spelling in windows services console
	'filezilla-server'
	'hMailServer'
	'ClamD'
	'mysql'
	'spamassassin'
	'Apache2.4'
	'syncthing'
)

#	'OpenVPNService'
#	'SEVPNSERVER'

###   EMAIL VARIABLES   ###
$FromAddress      = 'notification.txt.alerts@gmail.com'
$Recipient        = '9173286699@tmomail.net'
$Subject          = 'Windows Service Fault'
$EmailBody        = 'C:\scripts\EmailBody.txt'
$FileAttachment   = 'C:\scripts\somefile.log'
$HTML             = $False
$SMTPServer       = 'smtp.gmail.com'
$SMTPAuthUser     = 'notification.txt.alerts@gmail.com'
$SMTPAuthPass     = 'Cs!ll@2010'
$SMTPPort         = 587
$SSL              = $True
$UseEmail         = $False

###   SMS VARIABLES   ###
$SMSTo            = 9173286699
$UseSMS           = $True