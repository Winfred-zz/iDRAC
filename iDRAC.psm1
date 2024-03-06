# get-help convert-idraccontrollerfilestoobjects -full
# get-help convert-idracfilestoobjects -full
# get-help convert-idracstoragefilestoobjects -full
# get-help convert-idracvdiskfilestoobjects -full
# get-help Get-AvailableBIOSVersions -full
# get-help Get-iDracAcPwrRcvry -full
# get-help Get-iDracBiosVersion -full
# get-help get-idracinfo -full
# get-help get-idracinfoallips -full
# get-help Get-idracinfocombined -full
# get-help get-idracinfocontroller -full
# get-help get-idracinfostorage -full
# get-help get-idracinfovdisks -full
# get-help get-multipleidracversion -full
# get-help invoke-idraccommand -full
# get-help Invoke-IPMICommand -full
# get-help repair-badidraccontrollerobjects -full
# get-help restart-idrac -full
# get-help set-idracntp -full
# get-help test-ping -full
# get-help update-dellbios -full
# get-help Update-DellBiosAutomatically -full
# get-help Update-iDracAcPwrRcvryToLast -full
# get-help update-idracfirmware -full

#=====================================================================
# Out-MyLogFile
#=====================================================================
Function Out-MyLogFile
{
<#
.SYNOPSIS
	Takes in from the pipeline and will write it to a file.
.DESCRIPTION
	Either appends or Overrides the data in the text file.
	This is mainly used for logging and fixes the issue where if you run multiple jobs at once that log to the same log file, the file is locked and you get an error.
.EXAMPLE
	"abcd" | Out-MyLogFile "D:\Temp\test.txt" -append
.EXAMPLE	
	"abcde" | Out-MyLogFile "D:\Temp\test.txt"
.NOTES
	Maybe it should be throwing an error? Not sure.
.LINK

#>
[cmdletbinding()]
param(
	[parameter(ValueFromPipeline)]$TextToWrite,
	[Parameter(Position=0, Mandatory=$True)]$FilePath,
	[Parameter(Position=1)][switch]$Append
)
	$i = 0 
	Do{
		$WriteError = $Null
		try
		{
			$TextToWrite | out-file -FilePath $FilePath -append:$Append
		}
		catch [System.IO.IOException] 
		{
			$i++
			$WriteError = $True
		}
	}until(!($WriteError) -or ($i -ge 100))
	if($WriteError)
	{
		write-host "Tried to write 100 times, to $FilePath but I failed each time." -fore red
	}
}

#=====================================================================
#Restart-iDrac
#=====================================================================
Function Restart-iDrac
{
<#
.SYNOPSIS
	reboots an idrac interface
.DESCRIPTION

.EXAMPLE
	Restart-iDrac 10.0.0.1
.NOTES
	needs RACADM installed.
.LINK

#>
Param(
[Parameter(Mandatory=$True)][ipaddress]$IPAddress
)
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password racreset soft --nocertwarn
}

#=====================================================================
#Set-iDracNTP
#=====================================================================
Function Set-iDracNTP
{
<#
.SYNOPSIS
	Sets NTP servers for an iDRAC and enables NTP
.DESCRIPTION

.EXAMPLE
	Set-iDracNTP -IPAddress 10.0.0.1 -PrimaryNTPServer 10.0.0.5 -SecondaryNTPServer 10.0.0.10
.EXAMPLE
	Set-iDracNTP -IPAddress 10.0.0.1 -PrimaryNTPServer 10.0.0.5 -SecondaryNTPServer 10.0.0.10 -TimeZone "America/Los_Angeles"
.NOTES
	
.LINK

#>
Param(
[Parameter(Mandatory=$True)][ipaddress]$IPAddress,
[Parameter(Mandatory=$True)][ipaddress]$PrimaryNTPServer,
[Parameter(Mandatory=$True)][ipaddress]$SecondaryNTPServer,
[Parameter]$TimeZone="America/Los_Angeles"
)
	$LogFilePath = join-path $PsScriptRoot "logs"
	$logfile = join-path $LogFilePath "Set-iDracNTP.log"
	$Message = "$(get-date) Setting NTP on $IPAddress. For details, see: PowerShell\Modules\iDRAC\ChangeLogs\$IPAddress.txt"
	$ChangeLog = "$($PsScriptRoot)\ChangeLogs\$IPAddress.txt"
	write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile

	$Message = "$(get-date) Setting NTP1 on $IPAddress"
	write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append; $Message | Out-MyLogFile $ChangeLog -Append
	racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password set idrac.NTPConfigGroup.ntp1 $PrimaryNTPServer --nocertwarn 2>&1 | Out-File $ChangeLog -Append
	$Message = "$(get-date) Setting NTP2 on $IPAddress"
	write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append; $Message | Out-MyLogFile $ChangeLog -Append
	racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password set idrac.NTPConfigGroup.ntp2 $SecondaryNTPServer --nocertwarn 2>&1 | Out-File $ChangeLog -Append

	$Message = "$(get-date) Setting idrac.NTPConfigGroup.NTPEnable Enabled on $IPAddress"
	write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append; $Message | Out-MyLogFile $ChangeLog -Append
	racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password set idrac.NTPConfigGroup.NTPEnable Enabled --nocertwarn 2>&1 | Out-File $ChangeLog -Append
	$Message = "$(get-date) Setting idrac.time.timezone $TimeZone on $IPAddress"
	write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append; $Message | Out-MyLogFile $ChangeLog -Append
	racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password set idrac.time.timezone $TimeZone --nocertwarn 2>&1 | Out-File $ChangeLog -Append
}

#=====================================================================
#Update-iDracFirmware
#=====================================================================
Function Update-iDracFirmware
{
<#
.SYNOPSIS
	Updates the iDRAC Firmware with one located in C:\DellUpdates\iDRACImages
.DESCRIPTION

.EXAMPLE
	Update-iDracFirmware 10.0.0.1 -Model C6320 -Version 2.63.60.61
.EXAMPLE
	Update-iDracFirmware 10.0.0.11 -Model R620 -Version 2.63.60.62
.NOTES
	
.LINK

#>
Param(
[Parameter(Position=0, Mandatory=$True)][ipaddress]$IPAddress,
[Parameter(Position=1, Mandatory=$True)][string]$Model,
[Parameter(Position=2, Mandatory=$True)][string]$Version
)
	$LogFilePath = join-path $PsScriptRoot "logs"
	$logfile = join-path $LogFilePath "Update-iDracFirmware.log"
	$ChangeLog = join-path (join-path $PsScriptRoot ChangeLogs) "$($IPAddress).txt"
	
	$FirmwarePath = "$(join-path $PsScriptRoot iDRACImages)\$($Model)\$($Version)"
	
	if(!(Test-path $FirmwarePath))
	{
		$Message = "$(get-date) No Firmware found for $FirmwarePath for $IPAddress"
		write-host $Message -fore red; $Message | Out-MyLogFile $logfile -append
		return
	}
	
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	$i = 0
	do{
		if(($RACADMOutput -match "racadm : ERROR: Unable to transfer image file to the RAC.") -or ($i -eq 0))
		{
			if($i -eq 0)
			{
				$Message = "$(get-date) Updating Firmware (model: $Model - version: $Version) on $IPAddress (takes about 20 minutes to reboot, up to 45 minutes to complete)"
			}else{
				$Message = "$(get-date) Retry:$i on $IPAddress"
			}
			write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append; $Message | Out-MyLogFile $ChangeLog -Append
			$RACADMOutput = racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password fwupdate -p -u -d $FirmwarePath --nocertwarn 2>&1
			$RACADMOutput | Out-File $ChangeLog -Append
		}
		$i++
	}while($i -lt 3)
	write-host $RACADMOutput
}

#=====================================================================
#Update-DellBios
#=====================================================================
Function Update-DellBios
{
<#
.SYNOPSIS
	Updates the Dell Bios with one located in Modules\iDRAC\BIOSUpdates
	
	WIL AUTOMATICALLY REBOOT THE SERVER
	
.DESCRIPTION
	Make sure the server is not booted into the Lifecycle Controller or you will receive error:
	[RED023: Lifecycle Controller in use. This job will start when Lifecycle Controller is available.]
	and will manually have to reboot.
.EXAMPLE
	Update-DellBios 8.8.8.8 -Model R640 -Version 2.2.11
.NOTES
	relies on RACADM.
	Takes about 3 minutes to upload the BIOS, 7 minutes to install the BIOS and 2 minutes to boot.
	
	This function will schedule the BIOS upgrade, but will not verify that it is completed.
	
	To see the status of the job, use this command:
	
	Invoke-iDracCommand -IPAddress $iDRACIP -Command "jobqueue view"
	
	To view the BIOS version, use this command:
	
	Invoke-iDracCommand -IPAddress $iDRACIP -Command "getversion -b"
.LINK

#>
Param(
[Parameter(Position=0, Mandatory=$True)][ipaddress]$IPAddress,
[Parameter(Position=1, Mandatory=$True)][string]$Model,
[Parameter(Position=2, Mandatory=$False)][string]$Version
)
	$LogFilePath = join-path $PsScriptRoot "logs"
	$logfile = join-path $LogFilePath "Update-DellBios.log"
	$ChangeLog = join-path (join-path $PsScriptRoot ChangeLogs) "$($IPAddress).txt"
	$BiosRootPath = join-path $PsScriptRoot "BIOSUpdates"
	$BiosPath = "$($BiosRootPath)\$($Model)\$($Version)\BIOS.EXE"
	
	$Message = "$(get-date) Update-DellBios for $IPAddress $BiosPath"
	$Message | Out-MyLogFile $ChangeLog -Append; $Message | Out-MyLogFile $logfile -append
	
	if(!(Test-path $BiosPath))
	{
		$Message = "$(get-date) No BIOS found for $BiosPath for $IPAddress"
		write-host $Message -fore red; $Message | Out-MyLogFile $logfile -append
		return
	}
	
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	$i = 0
	do{
		if(($RACADMOutput -match "racadm : ERROR: Unable to transfer image file to the RAC.") -or ($i -eq 0))
		{
			if($i -eq 0)
			{
				$Message = "$(get-date) Updating BIOS (model: $Model) on $IPAddress"
			}else{
				$Message = "$(get-date) Retry:$i on $IPAddress"
			}
			write-host "WARNING - THIS WILL AUTOMATICALLY REBOOT THE COMPUTER AFTER UPLOADING THE BIOS" -fore red
			Start-sleep 10
			write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append; $Message | Out-MyLogFile $ChangeLog -Append
			$RACADMOutput = racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password update -f $BiosPath --reboot --nocertwarn 2>&1
			$RACADMOutput | Out-File $ChangeLog -Append
		}
		$i++
	}while($i -lt 3)
	write-host $RACADMOutput
}

#=====================================================================
#Update-DellRaidController
#=====================================================================
Function Update-DellRaidController
{
<#
.SYNOPSIS
	Updates the RAID Controller Firmware with one located in C:\DellUpdates\RaidControllerUpdates
	
	WIL AUTOMATICALLY REBOOT THE SERVER
	
.DESCRIPTION
	Make sure the server is not booted into the Lifecycle Controller or you will receive error:
	[RED023: Lifecycle Controller in use. This job will start when Lifecycle Controller is available.]
	and will manually have to reboot.
.EXAMPLE
	Update-DellRaidController 10.0.0.1 -Model R630 -Version 25.5.6.0009
.NOTES
	relies on RACADM.
	
	This function will schedule the RAID Controller Firmware, but will not verify that it is completed.
	
	To see the status of the job, use this command:
	
	Invoke-iDracCommand -IPAddress $iDRACIP -Command "jobqueue view"
	
	To view the Firmware version, use this command:
	
	Invoke-iDracCommand -IPAddress $iDRACIP -Command "raid get controllers -o"
.LINK

#>
Param(
[Parameter(Position=0, Mandatory=$True)][ipaddress]$IPAddress,
[Parameter(Position=1, Mandatory=$True)][string]$Model,
[Parameter(Position=2, Mandatory=$True)][string]$Version
)
	$LogFilePath = join-path $PsScriptRoot "logs"
	$logfile = join-path $LogFilePath "Update-DellRaidController.log"
	$ChangeLog = "$($PsScriptRoot)\ChangeLogs\$IPAddress.txt"
	
	$BiosPath = "$($PsScriptRoot)\RaidControllerUpdates\$($Model)\$($Version)\RAID.EXE"
	
	$Message = "$(get-date) Update-DellRaidController for $IPAddress $BiosPath"
	$Message | Out-MyLogFile $ChangeLog -Append; $Message | Out-MyLogFile $logfile -append
	
	if(!(Test-path $BiosPath))
	{
		$Message = "$(get-date) No BIOS found for $BiosPath for $IPAddress"
		write-host $Message -fore red; $Message | Out-MyLogFile $logfile -append
		return
	}
	
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	$i = 0
	do{
		if(($RACADMOutput -match "racadm : ERROR: Unable to transfer image file to the RAC.") -or ($i -eq 0))
		{
			if($i -eq 0)
			{
				$Message = "$(get-date) Updating firmware (model: $Model) on $IPAddress"
			}else{
				$Message = "$(get-date) Retry:$i on $IPAddress"
			}
			write-host "WARNING - THIS WILL AUTOMATICALLY REBOOT THE COMPUTER AFTER UPLOADING THE BIOS" -fore red
			Start-sleep 10
			write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append; $Message | Out-MyLogFile $ChangeLog -Append
			$RACADMOutput = racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password update -f $BiosPath --reboot --nocertwarn 2>&1
			$RACADMOutput | Out-File $ChangeLog -Append
		}
		$i++
	}while($i -lt 3)
	write-host $RACADMOutput
}

#=====================================================================
#Update-DellEnclosure
#=====================================================================
Function Update-DellEnclosure
{
<#
.SYNOPSIS
	Updates the RAID Controller Firmware with one located in C:\DellUpdates\EnclosureUpdates
	
	WIL AUTOMATICALLY REBOOT THE SERVER
	
.DESCRIPTION
	Make sure the server is not booted into the Lifecycle Controller or you will receive error:
	[RED023: Lifecycle Controller in use. This job will start when Lifecycle Controller is available.]
	and will manually have to reboot.
.EXAMPLE
	Update-DellEnclosure 10.0.0.1 -Model MD1420 -Version 1.07
.NOTES
	relies on RACADM.
	
	This function will schedule the Enclosure Firmware, but will not verify that it is completed.
	
	To see the status of the job, use this command:
	
	Invoke-iDracCommand -IPAddress $iDRACIP -Command "jobqueue view"
	
	To view the Firmware version, use this command:
	
	Invoke-iDracCommand -IPAddress $iDRACIP -Command "raid get controllers -o"
.LINK

#>
Param(
[Parameter(Position=0, Mandatory=$True)][ipaddress]$IPAddress,
[Parameter(Position=1, Mandatory=$True)][string]$Model,
[Parameter(Position=2, Mandatory=$True)][string]$Version
)
	$LogFilePath = join-path $PsScriptRoot "logs"
	$logfile = join-path $LogFilePath "Update-DellEnclosure.log"
	$ChangeLog = "$($PsScriptRoot)\ChangeLogs\$IPAddress.txt"
	
	$BiosPath = "$($PsScriptRoot)\EnclosureUpdates\$($Model)\$($Version)\Enclosure.EXE"
	
	$Message = "$(get-date) Update-DellEnclosure for $IPAddress $BiosPath"
	$Message | Out-MyLogFile $ChangeLog -Append; $Message | Out-MyLogFile $logfile -append
	
	if(!(Test-path $BiosPath))
	{
		$Message = "$(get-date) No Firmware found for $BiosPath for $IPAddress"
		write-host $Message -fore red; $Message | Out-MyLogFile $logfile -append
		return
	}
	
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	$i = 0
	do{
		if(($RACADMOutput -match "racadm : ERROR: Unable to transfer image file to the RAC.") -or ($i -eq 0))
		{
			if($i -eq 0)
			{
				$Message = "$(get-date) Updating Firmware (model: $Model) on $IPAddress"
			}else{
				$Message = "$(get-date) Retry:$i on $IPAddress"
			}
			write-host "WARNING - THIS WILL AUTOMATICALLY REBOOT THE COMPUTER AFTER UPLOADING THE BIOS" -fore red
			Start-sleep 10
			write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append; $Message | Out-MyLogFile $ChangeLog -Append
			$RACADMOutput = racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password update -f $BiosPath --reboot --nocertwarn 2>&1
			$RACADMOutput | Out-File $ChangeLog -Append
		}
		$i++
	}while($i -lt 3)
	write-host $RACADMOutput
}

#=====================================================================
#Invoke-iDracCommand
#=====================================================================
Function Invoke-iDracCommand
{
<#
.SYNOPSIS
	executes a RACADM command.
.DESCRIPTION

.EXAMPLE
	Invoke-iDracCommand -IPAddress 10.0.0.1 -Command "getversion -b"
.EXAMPLE	
	Invoke-iDracCommand -IPAddress 10.0.0.1 -Command "set iDRAC.AutoOSLock.AutoOSLockState Disabled"
.NOTES
	
.LINK

#>
Param(
[Parameter(Mandatory=$True)][ipaddress]$IPAddress,
[Parameter(Mandatory=$True)][string]$Command,
[Switch]$Raw
)
	$LogFilePath = join-path $PsScriptRoot "logs"
	$logfile = join-path $LogFilePath "Invoke-iDracCommand.log"
	
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	$Password = ($creds.GetNetworkCredential().password.replace("&","``&")).replace('(','`(')
	$RACADMCommand = "racadm -r $IPAddress -u root -p $($Password) $Command --nocertwarn 2>&1"
	"$(get-date) racadm -r $IPAddress -u root -p password $Command --nocertwarn" | Out-MyLogFile $logfile -Append
	Invoke-Expression $RACADMCommand
}

#=====================================================================
#Invoke-IPMICommand
#=====================================================================
Function Invoke-IPMICommand
{
<#
.SYNOPSIS
	executes a IPMI command.
.DESCRIPTION

.EXAMPLE
	Invoke-IPMICommand -IPAddress 10.0.0.1 -Command "chassis status"
.EXAMPLE
	Invoke-IPMICommand -IPAddress 10.0.0.1 -Command 'sdr type "Power Supply"'
.NOTES
	
.LINK

#>
Param(
[Parameter(Mandatory=$True)][ipaddress]$IPAddress,
[Parameter(Mandatory=$True)][string]$Command,
[Switch]$Raw
)
	$LogFilePath = join-path $PsScriptRoot "logs"
	$logfile = join-path $LogFilePath "Invoke-IPMICommand.log"
	
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	$Password = ($creds.GetNetworkCredential().password.replace("&","``&")).replace('(','`(')
	$IPMICommand = "ipmitool -I lanplus -U root -H $IPAddress -P $($Password) $Command"
	"ipmitool -I lanplus -U root -H $IPAddress -P password $Command" | Out-MyLogFile $logfile -Append
	Invoke-Expression $IPMICommand
}



#=====================================================================
#Get-iDracInfoCombined
#=====================================================================
Function Get-iDracInfoCombined
{
<#
.SYNOPSIS
	Runs the following export commands:
	Get-iDracInfoStorage
	Get-iDracInfoController
	Get-iDracInfo
	Get-iDracInfovDisks
	
	These are used by Get-iDracInfoAllIPs, so that the commands are changed into a single job, reducing the total number of jobs.
	
.DESCRIPTION

.EXAMPLE
	Get-iDracInfoCombined 10.0.0.1
.NOTES
	
.LINK

#>
Param(
[Parameter(Mandatory=$True)][ipaddress]$IPAddress
)
	$Null = Get-iDracInfoStorage -IPAddress $IPAddress
	$Null = Get-iDracInfoController -IPAddress $IPAddress
	$Null = Get-iDracInfo -IPAddress $IPAddress
	$Null = Get-iDracInfovDisks -IPAddress $IPAddress
}


#=====================================================================
#Get-iDracInfo
#=====================================================================
Function Get-iDracInfo
{
<#
.SYNOPSIS
	Connects to the iDRAC of a server and exports the configuration to a TXT named after the IP address.
.DESCRIPTION

.EXAMPLE
	Get-iDracInfo 10.0.0.1
.NOTES
	
.LINK

#>
Param(
[Parameter(Mandatory=$True)][ipaddress]$IPAddress
)
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password getsysinfo --nocertwarn 2>&1 | Out-File "$($PsScriptRoot)\Output\$IPAddress.txt"
}

#=====================================================================
#Get-iDracInfoStorage
#=====================================================================
Function Get-iDracInfoStorage
{
<#
.SYNOPSIS
	Connects to the iDRAC of a server and exports the Physical Hard Disk configuration to a TXT named after the IP address.
.DESCRIPTION

.EXAMPLE
	Get-iDracInfoStorage 10.0.0.1
.NOTES
	
.LINK

#>
Param(
[Parameter(Mandatory=$True)][ipaddress]$IPAddress
)
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password raid get pdisks -o --nocertwarn 2>&1 | Out-File "$($PsScriptRoot)\Output-Storage\$IPAddress.txt"
}

#=====================================================================
#Get-iDracInfovDisks
#=====================================================================
Function Get-iDracInfovDisks
{
<#
.SYNOPSIS
	Connects to the iDRAC of a server and exports the Physical Hard Disk configuration to a TXT named after the IP address.
.DESCRIPTION

.EXAMPLE
	Get-iDracInfovDisks 10.0.0.1
.NOTES
	
.LINK

#>
Param(
[Parameter(Mandatory=$True)][ipaddress]$IPAddress
)
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password raid get vdisks -o --nocertwarn 2>&1 | Out-File "$($PsScriptRoot)\Output-vDisks\$IPAddress.txt"
}

#=====================================================================
#Get-iDracInfoController
#=====================================================================
Function Get-iDracInfoController
{
<#
.SYNOPSIS
	Connects to the iDRAC of a server and exports the Controller configuration to a TXT named after the IP address.
.DESCRIPTION

.EXAMPLE
	Get-iDracInfoController 10.0.0.1
.NOTES
	
.LINK

#>
Param(
[Parameter(Mandatory=$True)][ipaddress]$IPAddress
)
	$CredsFile = join-path $PsScriptRoot "iDRAC-Creds-$($env:Username).xml"
	$creds = Get-MyCredential $CredsFile
	racadm -r $IPAddress -u root -p $creds.GetNetworkCredential().password raid get controllers -o --nocertwarn 2>&1 | Out-File "$($PsScriptRoot)\Output-Controllers\$IPAddress.txt"
}

#=====================================================================
#Get-iDracInfoAllIPs
#=====================================================================
Function Get-iDracInfoAllIPs
{
<#
.SYNOPSIS
	Connects to all iDRAC IPs of a subnet and exports the configuration to a TXT named after the IP address.
.DESCRIPTION
	Function is not subnet aware, everything is a /24.
.EXAMPLE
	Gets all the idrac information (including controllers and disks):
	Get-iDracInfoAllIPs -IPRanges (10.0.0.0,10.0.10.0)
.EXAMPLE
	Only gets the basic info (in case you need it fast)
	Get-iDracInfoAllIPs -JustInfo
.PARAMETER
	
.NOTES
	Relies on:
	Get-iDracInfo
	get-MultiplePingStatus
	Get-iDracInfoStorage
	Get-iDracInfoController
	Get-iDracInfovDisks
.LINK

#>
param(
	[Parameter(Mandatory=$True)][ipaddress]$IPRanges,
	[switch]$JustInfo
)
	$LogFilePath = join-path $PsScriptRoot "logs"
	$logfile = join-path $LogFilePath "Get-iDracInfoAllIPs.log"
	$Message = "$(get-date) Collecting all iDRAC details now."
	write-host $Message -fore cyan
	$Message | Out-MyLogFile $logfile -append
	$IPRangesInternal = @()
	
	foreach($IPrange in $IPRanges)
	{
		$IPs = @()
		0..255 | foreach-object{$IPs += "$($IP.Split('.')[0]).$($IP.Split('.')[1]).$($IPrange.Split('.')[2]).$($_)"}
		$IPRangesInternal += $IPs
	}

	get-job | remove-job
	$Done = $Null
	$TotalJobCount = 0
	$i = 0
	Do{
		$ArrayStart = $i
		$ArrayEnd = $i + 49
		if(($ArrayEnd) -gt ($IPRangesInternal.Count - 1))
		{
			$ArrayEnd = ($IPRangesInternal.Count - 1)
			$Done = $True
		}
		Start-Job -scriptblock ${function:get-MultiplePingStatus} -ArgumentList (,$IPRangesInternal[$ArrayStart..$ArrayEnd])
		$i = $i + 50
		$TotalJobCount++
	}Until($Done)
	
	do{
		start-sleep 10
		$NotCompletedCount = ((get-job).state -ne "Completed").count
		write-host "PingJobs Still running: $NotCompletedCount of $TotalJobCount"
	}until($NotCompletedCount -eq 0)
	
	$PingableIPs = @()

	Foreach($Job in (get-job))
	{
		$PingableIPs += receive-job -id $Job.Id
	}
	get-job | remove-job

	# Runs in batches of 15 simultanious jobs per 2 minutes (more than 20 at once and it'll hang forever and never completes).
	$i = 0
	
	Get-ChildItem -Path "$($PsScriptRoot)\Output" | Move-Item -Destination "$($PsScriptRoot)\Output-old" -force
	$Message = "$(get-date) Collecting all iDracInfo details now."
	write-host $Message -fore cyan
	$Message | Out-MyLogFile $logfile -append
	Foreach($IP in $PingableIPs)
	{
		$Null = Start-Job -scriptblock ${function:Get-iDracInfo} -ArgumentList $IP
		if(((get-job).state -ne "Completed").count -ge 30)
		{
			do{
				start-sleep 10
			}until(((get-job).state -ne "Completed").count -lt 30)
			write-host $IP
		}
	}
	get-job -State Completed | remove-job

	if(!$JustInfo)
	{
		Get-ChildItem -Path "$($PsScriptRoot)\Output-Storage" | Move-Item -Destination "$($PsScriptRoot)\Output-Storage-old" -force
		Get-ChildItem -Path "$($PsScriptRoot)\Output-Controllers" | Move-Item -Destination "$($PsScriptRoot)\Output-Controllers-old" -force
		Get-ChildItem -Path "$($PsScriptRoot)\Output-vDisks" | Move-Item -Destination "$($PsScriptRoot)\Output-vDisks-old" -force

		$Message = "$(get-date) Collecting all iDracInfoStorage details now."
		write-host $Message -fore cyan
		$Message | Out-MyLogFile $logfile -append
		Foreach($IP in $PingableIPs)
		{
			$Null = Start-Job -scriptblock ${function:Get-iDracInfoStorage} -ArgumentList $IP
			if(((get-job).state -ne "Completed").count -ge 30)
			{
				do{
					start-sleep 10
				}until(((get-job).state -ne "Completed").count -lt 30)
				write-host $IP
			}
		}
		get-job -State Completed | remove-job
		
		$Message = "$(get-date) Collecting all iDracInfoController details now."
		write-host $Message -fore cyan
		$Message | Out-MyLogFile $logfile -append
		Foreach($IP in $PingableIPs)
		{
			$Null = Start-Job -scriptblock ${function:Get-iDracInfoController} -ArgumentList $IP
			if(((get-job).state -ne "Completed").count -ge 30)
			{
				do{
					start-sleep 10
				}until(((get-job).state -ne "Completed").count -lt 30)
				write-host $IP
			}
		}
		get-job -State Completed | remove-job
		
		$Message = "$(get-date) Collecting all iDracInfovDisks details now."
		write-host $Message -fore cyan
		$Message | Out-MyLogFile $logfile -append
		Foreach($IP in $PingableIPs)
		{
			$Null = Start-Job -scriptblock ${function:Get-iDracInfovDisks} -ArgumentList $IP
			if(((get-job).state -ne "Completed").count -ge 30)
			{
				do{
					start-sleep 10
				}until(((get-job).state -ne "Completed").count -lt 30)
				write-host $IP
			}
		}
	}
	start-sleep 90
	get-job -State Completed | remove-job
	
	$ArrayOfiDRACObjects = Convert-iDRACFilesToObjects
	$ArrayOfiDRACObjects | export-clixml "$($PsScriptRoot)\ArrayOfiDRACObjects.xml"
	if(!$JustInfo)
	{
		$ArrayOfControllerObjects = Convert-iDRACControllerFilesToObjects
		$ArrayOfControllerObjects | export-clixml "$($PsScriptRoot)\ArrayOfControllerObjects.xml"
		$ArrayOfStorageObjects = Convert-iDRACStorageFilesToObjects
		$ArrayOfStorageObjects | export-clixml "$($PsScriptRoot)\ArrayOfStorageObjects.xml"
		$ArrayOfExternalStorageObjects = Convert-iDRACStorageFilesToObjects -External
		$ArrayOfExternalStorageObjects | export-clixml "$($PsScriptRoot)\ArrayOfExternalStorageObjects.xml"
		$ArrayOfvDiskObjects = Convert-iDRACvDiskFilesToObjects
		$ArrayOfvDiskObjects | export-clixml "$($PsScriptRoot)\ArrayOfvDiskObjects.xml"
	}
	
	$Message = "$(get-date) All Done"
	write-host $Message -fore cyan
	$Message | Out-MyLogFile $logfile -append
}

#=====================================================================
#Repair-BADiDRACControllerObjects
#=====================================================================
Function Repair-BADiDRACControllerObjects
{
<#
.SYNOPSIS
	If an iDRAC has not been rebooted for a long time, the controller objects can become corrupt. This can be fixed by rebooting the idrac.
	This function finds all the bad controller objects and redownloads them. It's a patch for a problem that should be fixed by rebooting the idrac.
.DESCRIPTION
	Finds and redownloads racadm output files that have hard disk properties listed in the controller section.
.EXAMPLE
	Repair-BADiDRACControllerObjects
.NOTES
	Just run this twice (or more times) to make sure that all controller objects are correct.
.LINK

#>
	$LogFilePath = join-path $PsScriptRoot "logs"
	$logfile = join-path $LogFilePath "Repair-BADiDRACControllerObjects.log"
	$Message = "$(get-date) Verifying all controller objects"
	write-host $Message -fore cyan
	$Message | Out-MyLogFile $logfile -append

	$ArrayOfControllerObjects = Import-clixml "$($PsScriptRoot)\ArrayOfControllerObjects.xml"
	foreach($Object in ($ArrayOfControllerObjects | where-object {$_.InUse}))
	{
		foreach($Controller in $Object.Controllers)
		{
			$NotePropertyNames = $Null
			$NotePropertyNames = $Controller | get-member | where-object {$_.MemberType -eq "NoteProperty"} | foreach-object {$_.Name}
			if(($NotePropertyNames -eq "Manufacturer") -or ($NotePropertyNames -eq "RaidNominalMediumRotationRate"))
			{
				$IP = $Null
				$IP = $Object.IP
				$Message = "$(get-date) Bad Controller Object $IP - Redownloading."
				write-host $Message -fore yellow
				$Message | Out-MyLogFile $logfile -append
				Get-iDracInfoController $IP
			}
		}
	}
	$ArrayOfControllerObjects = Convert-iDRACControllerFilesToObjects
	$ArrayOfControllerObjects | export-clixml "$($PsScriptRoot)\ArrayOfControllerObjects.xml"
}

#=====================================================================
#Convert-iDRACFilesToObjects
#=====================================================================
Function Convert-iDRACFilesToObjects
{
<#
.SYNOPSIS
	Imports the iDRAC files in PowerShell\Modules\iDRAC\Output and turns them into an array of objects.
.DESCRIPTION

.EXAMPLE
	$ArrayOfiDRACObjects = Convert-iDRACFilesToObjects
	$ArrayOfiDRACObjects | export-clixml "$($PsScriptRoot)\ArrayOfiDRACObjects.xml"
.NOTES
	uses output of Get-iDracInfo and Get-iDracInfoAllIPs
.LINK

#>
	$iDracFiles = get-childitem "$($PsScriptRoot)\Output"

	$ArrayOfObjects = @()

	foreach($iDracFile in $iDracFiles)
	{
		$Object = New-Object -TypeName System.Object 
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "iDracFileContent" -Value (get-content $iDracFile.FullName)
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "IP" -Value $iDracFile.BaseName
		$ArrayOfObjects += $Object
	}

	# Determine if IP is inuse as an idrac or not.
	foreach($Object in $ArrayOfObjects)
	{
		if(($Object.iDracFileContent[0] -eq "racadm : ERROR: Unable to connect to RAC at specified IP address.") -or ($Object.iDracFileContent[1] -eq "racadm : ERROR: Unable to connect to RAC at specified IP address."))
		{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $False -force
		}else{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $True -force
		}
		if($Object.iDracFileContent[3] -eq "racadm : ERROR: Login failed - invalid username or password")
		{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InCorrectUserNameOrPassword" -Value $True -force
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $False -force
		}
		# This is for ME4024 workaround.
		if(!($object.iDracFileContent -match "="))
		{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $False -force
		}
	}

	# splits each line by equal sign, then adds the first part as a property and the second part as a value.
	# excludes :: since that's related to IPv6
	foreach($Object in ($ArrayOfObjects | where-object {$_.Inuse}))
	{
		write-host $Object.IP
		
		foreach($Line in $Object.iDracFileContent)
		{
			if(($Line -match "=") -and !($Line -match "::"))
			{
				Add-Member -inputObject $Object -MemberType NoteProperty -Name $Line.split("=")[0].Trim() -Value $Line.split("=")[1].Trim() -Force
			}
		}
	}
	return $ArrayOfObjects
}

#=====================================================================
#Convert-iDRACStorageFilesToObjects
#=====================================================================
Function Convert-iDRACStorageFilesToObjects
{
<#
.SYNOPSIS
	Imports the iDRAC files in PowerShell\Modules\iDRAC\Output and turns them into an array of objects.
.DESCRIPTION

.EXAMPLE
	$ArrayOfStorageObjects = Convert-iDRACStorageFilesToObjects
	$ArrayOfStorageObjects | export-clixml "$($PsScriptRoot)\ArrayOfStorageObjects.xml"
.EXAMPLE
	$ArrayOfExternalStorageObjects = Convert-iDRACStorageFilesToObjects -External
	$ArrayOfExternalStorageObjects | export-clixml "$($PsScriptRoot)\ArrayOfExternalStorageObjects.xml"
.NOTES
	uses output of Get-iDracInfo and Get-iDracInfoAllIPs, which stores the output in "$($PsScriptRoot)\Output"
.LINK

#>
param(
[switch]$External
)
	$iDracFiles = get-childitem "$($PsScriptRoot)\Output-Storage"

	$ArrayOfObjects = @()

	foreach($iDracFile in $iDracFiles)
	{
		$Object = New-Object -TypeName System.Object 
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "iDracFileContent" -Value (get-content $iDracFile.FullName)
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "IP" -Value $iDracFile.BaseName
		$ArrayOfObjects += $Object
	}

	# Determine if IP is inuse as an idrac or not.
	foreach($Object in $ArrayOfObjects)
	{
		if(($Object.iDracFileContent[0] -eq "racadm : ERROR: Unable to connect to RAC at specified IP address.") -or `
		($Object.iDracFileContent[1] -eq "racadm : ERROR: Unable to connect to RAC at specified IP address.") -or `
		($Object.iDracFileContent[4] -eq "ERROR: STOR0103 : No physical disks are displayed."))
		{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $False -force
		}else{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $True -force
		}
		if($Object.iDracFileContent[3] -eq "racadm : ERROR: Login failed - invalid username or password")
		{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InCorrectUserNameOrPassword" -Value $True -force
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $False -force
		}
	}

	# splits each line by equal sign, then adds the first part as a property and the second part as a value.
	# excludes :: since that's related to IPv6
	foreach($Object in ($ArrayOfObjects | where-object {$_.Inuse}))
	{
		write-host $Object.IP
		
		$HardDiskStartArray = @()
		$HardDiskEndArray = @()
		$i = 0
		foreach($Line in $Object.iDracFileContent)
		{
			# Figure out where a disk starts:
			if($Line.StartsWith("Disk.Bay."))
			{
				# if we already found one disk
				if($HardDiskStartArray)
				{
					# Then the end of the first disk is the start of the next disk minus one line.
					$HardDiskEndArray += $i - 1
				}
				$HardDiskStartArray += $i
			}
			$i++
		}
		if(!$HardDiskStartArray)
		{
			$HardDiskStartArray = @()
			$HardDiskEndArray = @()
			$i = 0
			foreach($Line in $Object.iDracFileContent)
			{
				# Figure out where a disk starts:
				if($Line.StartsWith("Disk.Direct."))
				{
					# if we already found one disk
					if($HardDiskStartArray)
					{
						# Then the end of the first disk is the start of the next disk minus one line.
						$HardDiskEndArray += $i - 1
					}
					$HardDiskStartArray += $i
				}
				$i++
			}
		}
		
		$HardDiskEndArray += $Object.iDracFileContent.Count
		
		$HardDiskObjectArray = @()
		$i = 0
		# for each start of a hard disk that we found ...
		foreach($HardDiskStart in $HardDiskStartArray)
		{
			# select the lines from beginning to end from iDracFileContent
			$HardDiskText = $Object.iDracFileContent[$HardDiskStart..($HardDiskEndArray[$i])]
			write-host $HardDiskText[0]
			
			if($External)
			{
				if($HardDiskText[0] -match "Enclosure.External")
				{
					$HardDiskObject = New-Object -TypeName System.Object
					Add-Member -inputObject $HardDiskObject -MemberType NoteProperty -Name "DiskBayLine" -Value $HardDiskText[0].Trim()
					ForEach($Line in $HardDiskText)
					{
						# and the line has an equal sign in it
						if($Line -match "=")
						{
							# then add a property/value pair to the hard disk object
							Add-Member -inputObject $HardDiskObject -MemberType NoteProperty -Name $Line.split("=")[0].Trim() -Value $Line.split("=")[1].Trim() -Force
						}
					}
					# sometimes the devicedescription just isn't there in the export (I think in older idrac firmwares). Then substitute the device description with the DiskBayLine
					if(!($HardDiskObject.DeviceDescription) -and ($HardDiskObject.DiskBayLine))
					{
						Add-Member -inputObject $HardDiskObject -MemberType NoteProperty -Name "DeviceDescription" -Value $HardDiskObject.DiskBayLine
					}
					
					$HardDiskObjectArray += $HardDiskObject
				}
			}else{
				# and if it is an internal hard disk,
				if(($HardDiskText[0] -match "Enclosure.Internal") -or ($HardDiskText[0] -match "Disk.Direct."))
				{
					$HardDiskObject = New-Object -TypeName System.Object
					Add-Member -inputObject $HardDiskObject -MemberType NoteProperty -Name "DiskBayLine" -Value $HardDiskText[0].Trim()
					ForEach($Line in $HardDiskText)
					{
						# and the line has an equal sign in it
						if($Line -match "=")
						{
							# then add a property/value pair to the hard disk object
							Add-Member -inputObject $HardDiskObject -MemberType NoteProperty -Name $Line.split("=")[0].Trim() -Value $Line.split("=")[1].Trim() -Force
						}
					}
					# sometimes the devicedescription just isn't there in the export (I think in older idrac firmwares). Then substitute the device description with the DiskBayLine
					if(!($HardDiskObject.DeviceDescription) -and ($HardDiskObject.DiskBayLine))
					{
						Add-Member -inputObject $HardDiskObject -MemberType NoteProperty -Name "DeviceDescription" -Value $HardDiskObject.DiskBayLine
					}
					
					$HardDiskObjectArray += $HardDiskObject
				}
			}
			
			$i ++
		}
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "HardDisks" -Value $HardDiskObjectArray -force
	}
	return $ArrayOfObjects
}

#=====================================================================
#Convert-iDRACControllerFilesToObjects
#=====================================================================
Function Convert-iDRACControllerFilesToObjects
{
<#
.SYNOPSIS
	Imports the iDRAC files in PowerShell\Modules\iDRAC\Output and turns them into an array of objects.
.DESCRIPTION

.EXAMPLE
	$ArrayOfControllerObjects = Convert-iDRACControllerFilesToObjects
	$ArrayOfControllerObjects | export-clixml "$($PsScriptRoot)\ArrayOfControllerObjects.xml"
.NOTES
	uses output of Get-iDracInfo and Get-iDracInfoAllIPs, which stores the output in "$($PsScriptRoot)\Output"
.LINK

#>
	$iDracFiles = get-childitem "$($PsScriptRoot)\Output-Controllers"

	$ArrayOfObjects = @()

	foreach($iDracFile in $iDracFiles)
	{
		$Object = New-Object -TypeName System.Object 
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "iDracFileContent" -Value (get-content $iDracFile.FullName)
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "IP" -Value $iDracFile.BaseName
		$ArrayOfObjects += $Object
	}

	# Determine if IP is inuse as an idrac or not.
	foreach($Object in $ArrayOfObjects)
	{
		if(($Object.iDracFileContent[0] -eq "racadm : ERROR: Unable to connect to RAC at specified IP address.") -or `
			($Object.iDracFileContent[1] -eq "racadm : ERROR: Unable to connect to RAC at specified IP address.") -or `
			($Object.iDracFileContent[4] -eq "ERROR: Invalid subcommand specified.") -or `
			($Object.iDracFileContent[4] -eq "ERROR: STOR0101 : No RAID controller is displayed."))
		{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $False -force
		}else{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $True -force
		}
		if($Object.iDracFileContent[3] -eq "racadm : ERROR: Login failed - invalid username or password")
		{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InCorrectUserNameOrPassword" -Value $True -force
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $False -force
		}
	}

	# splits each line by equal sign, then adds the first part as a property and the second part as a value.
	foreach($Object in ($ArrayOfObjects | where-object {$_.Inuse}))
	{
		write-host $Object.IP
		
		$ControllerStartArray = @()
		$ControllerEndArray = @()
		$i = 0
		foreach($Line in $Object.iDracFileContent)
		{
			# Figure out where a Controller starts:
			if(($Line.StartsWith("RAID.")) -or ($Line.StartsWith("AHCI.")))
			{
				# if we already found one controller or disk:
				if($ControllerStartArray)
				{
					# Then the end of the first controller is the start of the next controller minus one line.
					# But only if we didn't already find a disk instead of a controller.
					if($ControllerStartArray.count -ne $ControllerEndArray.count)
					{
						$ControllerEndArray += $i - 1
					}
				}
				$ControllerStartArray += $i
			}
			if($ControllerStartArray.count -ne $ControllerEndArray.count)
			{
				# this means we found the start of one controller, but not the end yet.
				if(($Line.StartsWith("Disk.Bay.")) -or ($Line.StartsWith("Disk.Direct.")))
				{
					$ControllerEndArray += $i - 1
				}
			}
			$i++
		}
		$ControllerEndArray += $Object.iDracFileContent.Count
		
		$ControllerObjectArray = @()
		$i = 0
		# for each start of a hard disk that we found ...
		foreach($ControllerStart in $ControllerStartArray)
		{
			# select the lines from beginning to end from iDracFileContent
			$ControllerText = $Object.iDracFileContent[$ControllerStart..($ControllerEndArray[$i])]
			write-host $ControllerText[0]

			$ControllerObject = New-Object -TypeName System.Object 
			ForEach($Line in $ControllerText)
			{
				# and the line has an equal sign in it
				if($Line -match "=")
				{
					# then add a property/value pair to the hard disk object
					Add-Member -inputObject $ControllerObject -MemberType NoteProperty -Name $Line.split("=")[0].Trim() -Value $Line.split("=")[1].Trim() -Force
				}
			}
			$ControllerObjectArray += $ControllerObject
			$i ++
		}
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "Controllers" -Value $ControllerObjectArray -force
	}
	foreach($Object in ($ArrayOfObjects | where-object {$_.InCorrectUserNameOrPassword}))
	{
		write-host "Found iDRAC with incorrect Username/Password:" -fore red
		write-host "$($Object.IP)" -fore red
	}
	
	return $ArrayOfObjects
}

#=====================================================================
#Convert-iDRACvDiskFilesToObjects
#=====================================================================
Function Convert-iDRACvDiskFilesToObjects
{
<#
.SYNOPSIS
	Imports the iDRAC files in PowerShell\Modules\iDRAC\Output and turns them into an array of objects.
.DESCRIPTION

.EXAMPLE
	$ArrayOfControllerObjects = Convert-iDRACvDiskFilesToObjects
.NOTES
	uses output of Get-iDracInfo and Get-iDracInfoAllIPs, which stores the output in "$($PsScriptRoot)\Output"
.LINK

#>
	$iDracFiles = get-childitem "$($PsScriptRoot)\Output-vDisks"

	$ArrayOfObjects = @()

	foreach($iDracFile in $iDracFiles)
	{
		$Object = New-Object -TypeName System.Object 
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "iDracFileContent" -Value (get-content $iDracFile.FullName)
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "IP" -Value $iDracFile.BaseName
		$ArrayOfObjects += $Object
	}

	# Determine if IP is inuse as an idrac or not.
	foreach($Object in $ArrayOfObjects)
	{
		if(($Object.iDracFileContent[0] -eq "racadm : ERROR: Unable to connect to RAC at specified IP address.") -or `
			($Object.iDracFileContent[3] -eq "racadm : ERROR: Unable to connect to RAC at specified IP address.") -or `
			($Object.iDracFileContent[6] -eq "ERROR: Invalid subcommand specified.") -or `
			($Object.iDracFileContent[6] -eq "ERROR: STOR0101 : No RAID controller is displayed."))
		{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $False -force
		}else{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $True -force
		}
		if($Object.iDracFileContent[3] -eq "racadm : ERROR: Login failed - invalid username or password")
		{
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InCorrectUserNameOrPassword" -Value $True -force
			Add-Member -inputObject $Object -MemberType NoteProperty -Name "InUse" -Value $False -force
		}
	}
	
	foreach($Object in ($ArrayOfObjects | where-object {$_.Inuse}))
	{
		write-host $Object.IP
		
		$vDiskStartArray = @()
		$vDiskEndArray = @()
		$i = 0
		foreach($Line in $Object.iDracFileContent)
		{
			# Figure out where a Controller starts:
			if($Line.StartsWith("Disk.Virtual."))
			{
				# if we already found one controller or disk:
				if($vDiskStartArray)
				{
					# Then the end of the first controller is the start of the next controller minus one line.
					# But only if we didn't already find a disk instead of a controller.
					if($vDiskStartArray.count -ne $vDiskEndArray.count)
					{
						$vDiskEndArray += $i - 1
					}
				}
				$vDiskStartArray += $i
			}
			$i++
		}
		$vDiskEndArray += $Object.iDracFileContent.Count
		
		$vDiskObjectArray = @()
		$i = 0
		# for each start of a hard disk that we found ...
		foreach($vDiskStart in $vDiskStartArray)
		{
			# select the lines from beginning to end from iDracFileContent
			$vDiskText = $Object.iDracFileContent[$vDiskStart..($vDiskEndArray[$i])]
			write-host $vDiskText[0]

			$vDiskObject = New-Object -TypeName System.Object 
			ForEach($Line in $vDiskText)
			{
				# and the line has an equal sign in it
				if($Line -match "=")
				{
					# then add a property/value pair to the hard disk object
					Add-Member -inputObject $vDiskObject -MemberType NoteProperty -Name $Line.split("=")[0].Trim() -Value $Line.split("=")[1].Trim() -Force
				}
			}
			$vDiskObjectArray += $vDiskObject
			$i ++
		}
		Add-Member -inputObject $Object -MemberType NoteProperty -Name "vDisks" -Value $vDiskObjectArray -force
	}
	foreach($Object in ($ArrayOfObjects | where-object {$_.InCorrectUserNameOrPassword}))
	{
		write-host "Found iDRAC with incorrect Username/Password:" -fore red
		write-host "$($Object.IP)" -fore red
	}
	
	return $ArrayOfObjects
}

#=====================================================================
#Test-Ping
#=====================================================================
Function Test-Ping
{
param(
	$ComputerName
)
	 try {
		$oPing = new-object system.net.networkinformation.ping;
	 if (($oPing.Send($ComputerName, 200).Status -eq 'TimedOut')) {
		$false;
	 } else {
		$true 
	 }
	 } catch [System.Exception] {
		$false
	 }
}


#=====================================================================
#Get-iDracBiosVersion
#=====================================================================
Function Get-iDracBiosVersion
{
<#
.SYNOPSIS
	gets the bios version as a string
.DESCRIPTION

.EXAMPLE
	Get-iDracBiosVersion -IPAddress $iDRACIP

.NOTES
	
.LINK

#>
param($IPAddress)

	$string = Invoke-iDracCommand -IPAddress $IPAddress -Command "getversion -b"
	if($string -match "=")
	{
		foreach($line in $string)
		{
			if($line -match "=")
			{
				$biosversion = $line.split("=")[1].trim()
				if($biosversion.length -gt 2)
				{
					return $biosversion
				}
			}
		}
	}
}

#=====================================================================
#Get-AvailableBIOSVersions
#=====================================================================
Function Get-AvailableBIOSVersions
{
<#
.SYNOPSIS
	returns all stored bioses in alphabetical order
.DESCRIPTION

.EXAMPLE
	Get-AvailableBIOSVersions -Model C6320

.NOTES
	Relies on a TXT file for the order.
.LINK

#>
param($Model)
	$rootFolder = "$($PsScriptRoot)\BIOSUpdates"
	$ModelFolder = join-path $rootFolder $Model
	if(!($ModelFolder))
	{
		return "failed to find model $Model in $rootFolder"
	}
	# better make sure there are at least two bioses, otherwise it'll probably return a string, not an array
	$subdirectoryNames = get-content (join-path $ModelFolder "firmwareversions.txt")
	return $subdirectoryNames
}

#=====================================================================
#Get-AvailableBIOSVersions
#=====================================================================
Function Update-DellBiosAutomatically
{
<#
.SYNOPSIS
	This will update dell servers in successive order
.DESCRIPTION

.EXAMPLE
	Update-DellBiosAutomatically -IPAddress 8.8.8.8 -Model C6320

.NOTES
	For this to function, the current BIOS version needs to be in C:\DellUpdates\BIOSUpdates

	It first finds the current version and then starts updating from there.

	Takes roughly 18 minutes per BIOS update, it's probably best to keep it like that.
.LINK

#>
param(
	[Parameter(Position=0, Mandatory=$True)][ipaddress]$IPAddress,
	[Parameter(Position=1, Mandatory=$True)][string]$Model
)
	$LogFilePath = join-path $PsScriptRoot "logs"
	$logfile = join-path $LogFilePath "Update-DellBiosAutomatically.log"
	$Message = "$(get-date) Update DellBiosAutomatically on $IPAddress model $Model"
	write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append
	if(!(Test-Ping $IPAddress))
	{
		$Message = "$(get-date) Unable to ping $IPAddress"
		write-host $Message -fore red; $Message | Out-MyLogFile $logfile -append
		return
	}
	$BiosVersions = Get-AvailableBIOSVersions -Model $Model

	$CurrentBiosVersion = Get-iDracBiosVersion -IPAddress $IPAddress
	$CurrentBiosFound = $false
	$BiosesToInstall = @()
	Foreach($BiosVersion in $BiosVersions)
	{
		if($CurrentBiosFound)
		{
			$BiosesToInstall += $BiosVersion
		}
		if($CurrentBiosVersion -eq $BiosVersion)
		{
			$Message = "$(get-date) Found current BIOS! $IPAddress with model $Model - CurrentBiosVersion found: $CurrentBiosVersion"
			write-host $Message -fore green; $Message | Out-MyLogFile $logfile -append
			$CurrentBiosFound = $True
		}
	}
	if(!($CurrentBiosFound))
	{
		$Message = "$(get-date) Unable to find current bios for $IPAddress with model $Model - Bios found on server: $CurrentBiosVersion"
		write-host $Message -fore red; $Message | Out-MyLogFile $logfile -append
		return
	}
	if($BiosesToInstall -eq 0)
	{
		$Message = "$(get-date) $IPAddress with model $Model - probably already latest bios"
		write-host $Message -fore green; $Message | Out-MyLogFile $logfile -append
	}
	foreach($BiosVersion in $BiosesToInstall)
	{
		$Message = "$(get-date) $IPAddress with model $Model -installing $BiosVersion"
		write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append
		Update-DellBios -IPAddress $IPAddress -Model $Model -Version $BiosVersion
		start-sleep 1000
		$BIOSVersionRightNow = Get-iDracBiosVersion -IPAddress $IPAddress
		$Message = "$(get-date) $IPAddress with model $Model after installing $BiosVersion we found $BIOSVersionRightNow"
		write-host $Message -fore cyan; $Message | Out-MyLogFile $logfile -append
		if(!($BiosVersion -eq $BIOSVersionRightNow))
		{
			$Message = "$(get-date) BIOS Upgrade for $IPAddress with model $Model failed to install $BiosVersion - current BIOS: $BIOSVersionRightNow"
			write-host $Message -fore red; $Message | Out-MyLogFile $logfile -append
			return
		}
	}
}

#=====================================================================
#Get-iDracAcPwrRcvry
#=====================================================================
Function Get-iDracAcPwrRcvry
{
<#
.SYNOPSIS
	Gets the current status of the AC recovery setting of a Dell server using RACADM
.DESCRIPTION
	It just outputs to console, doesn't do anything else. 
.EXAMPLE
	Get-iDracAcPwrRcvry -IPAddress 10.0.0.0
.PARAMETER IPAddress
	The IP Address of the Idrac
.NOTES
	Used by Change-iDracAcPwrRcvryToLast
#>
param($IPAddress)
	Invoke-iDracCommand -IPAddress $IPAddress -Command "get BIOS.SysSecurity.AcPwrRcvry"
}

#=====================================================================
#Update-iDracAcPwrRcvryToLast
#=====================================================================
Function Update-iDracAcPwrRcvryToLast
{
<#
.SYNOPSIS
	This will Update the AC Power recovery to last status.
.DESCRIPTION
	That means if the server is shut down and power is lost, the server will stay down.
	If the server is on and power is lost, the server will start up when power is restored.
.EXAMPLE
	Update-iDracAcPwrRcvryToLast -IPAddress 10.0.0.0
.PARAMETER IPAddress
	The IP Address of the Idrac
.NOTES
	Sometimes a server can get stuck on the "serveraction hardreset"
	This software doesn't take that into account and will keep looping until manual intervention takes place.
	
	Then a manual Invoke-iDracCommand -IPAddress 10.0.0.0 -Command "serveraction hardreset" has to be issued.
	
	This does not shut down the server. You can use this command for that:
	
	stop-computer -ComputerName computername -Force

#>
param($IPAddress)
	$Output = $Null
	$Output = Get-iDracAcPwrRcvry -IPAddress $IPAddress
	if(!($Output))
	{
		write-host "Update-iDracAcPwrRcvryToLast - $IPAddress - failed to query idrac" -fore red
		return
	}
	$AcPwrRcvryLine = $Output | where-object {$_.startswith("AcPwrRcvry")}
	if($AcPwrRcvryLine -eq "AcPwrRcvry=Last")
	{
		write-host "Update-iDracAcPwrRcvryToLast - $IPAddress - already set to AcPwrRcvry=Last" -fore Green
		return
	}
	Invoke-iDracCommand -IPAddress $IPAddress -Command "set BIOS.SysSecurity.AcPwrRcvry Last"; 
	Invoke-iDracCommand -IPAddress $IPAddress -Command "jobqueue create BIOS.Setup.1-1"; 
	Invoke-iDracCommand -IPAddress $IPAddress -Command "serveraction hardreset"
	Do{
		$Output = Get-iDracAcPwrRcvry -IPAddress $IPAddress
		$AcPwrRcvryLine = $Null
		$AcPwrRcvryLine = $Output | where-object {$_.startswith("AcPwrRcvry")}
		if($AcPwrRcvryLine -eq "AcPwrRcvry=Last")
		{
			write-host "Update-iDracAcPwrRcvryToLast- done with $IPAddress"
			break
		}else{
			write-host "Update-iDracAcPwrRcvryToLast - in progress - AcPwrRcvryLine: $AcPwrRcvryLine"
		}
		start-sleep 30
	}while($True)
}






#=====================================================================
#Update-Delldisplay
#=====================================================================
Function Update-Delldisplay
{
<#
.SYNOPSIS
	This will change what is displayed on the dell servers with displays (R620,R630s and R640s)
.DESCRIPTION

.EXAMPLE
	Update-DellBiosAutomatically -IPAddress 8.8.8.8 -Model C6320

.NOTES

.LINK

#>
param(
	[Parameter(Position=0, Mandatory=$True)][ipaddress]$IPAddress,
	[Parameter(Position=1, Mandatory=$True)][string]$DisplayString
)
	Invoke-iDracCommand -IPAddress $IPAddress -Command "set System.LCD.Configuration" # incorrect, read the manual to see what we can actually do.
}


#=====================================================================
# Get-MyCredential
#=====================================================================
function Get-MyCredential
{
<#
.SYNOPSIS
	Get-MyCredential
.DESCRIPTION
	If a credential is stored in $CredPath, it will be used.
	If no credential is found, Export-Credential will start and offer to
	Store a credential at the location specified.
.EXAMPLE
	Get-MyCredential -CredPath `$CredPath
.NOTES

.LINK


#>
param(
[Parameter(Position=0, Mandatory=$true)]$CredPath,
$UserName
)
	if (!(Test-Path -Path $CredPath -PathType Leaf)) {
		Export-Credential (Get-Credential -Credential $UserName) $CredPath
	}
	$cred = Import-Clixml $CredPath
	$cred.Password = $cred.Password | ConvertTo-SecureString
	$Credential = New-Object System.Management.Automation.PsCredential($cred.UserName, $cred.Password)
	Return $Credential
}
#=====================================================================
# Export-Credential
#=====================================================================
function Export-Credential
<#
.SYNOPSIS
	
.DESCRIPTION
	This saves a credential to an XML File, for use with Get-MyCredential
.EXAMPLE
	Export-Credential $CredentialObject $FileToSaveTo
.NOTES

.LINK

#>
{
param(
$cred,
$path
)
      $cred = $cred | Select-Object *
      $cred.password = $cred.Password | ConvertFrom-SecureString
      $cred | Export-Clixml $path
}

#=====================================================================
#function get-MultiplePingStatus
#=====================================================================
function get-MultiplePingStatus
{
<#
.SYNOPSIS
	Pings multiple IPs in order, only returns the IPs that are responding.
.DESCRIPTION

.EXAMPLE
	get-MultiplePingStatus -IPs ("1.1.1.1","1.1.1.2")
.NOTES

.LINK

#>
param(
$IPs
)
$IPsToReturn = @()
	Foreach($IP in $IPs)
	{
		if(get-PingStatus $IP)
		{
			$IPsToReturn += $IP
		}
	}
	if($IPsToReturn)
	{
		Return $IPsToReturn
	}
}