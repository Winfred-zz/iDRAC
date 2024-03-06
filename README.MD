# iDRAC Windows PowerShell Module.

This module requires that you have racadm in your path variable (which I think will happen automatically after installation you can test this by executing "racadm" from the commandline).

The first time you run one of the commands, it will ask for a credential that will securely be stored in the module folder.

To automatically install BIOS, iDRAC Firmware or raid controller firmware:

There is a directory in the module folder for each

Then make a sub folder for the server (eg: R640, C6320)

Then make a sub folder that has the version name (whichever name you give here needs to be referenced).

And name the file either RAID.EXE, BIOS.EXE or FIRMWARE.EXE

So this command:

Update-DellRaidController 10.0.0.1 -Model R630 -Version 25.5.6.0009

Will try to install: PowerShell\Modules\iDRAC\R630\25.5.6.0009\RAID.EXE on the server.

[Download RacADM](https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=9dd9y)

