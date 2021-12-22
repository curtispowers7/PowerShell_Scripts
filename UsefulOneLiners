#Move workstation to different OU using ADSI:
([adsi]"$(([adsisearcher]"(samaccountname=$ComputerName$)").findone().path)").psbase.MoveTo([adsi]"LDAP://$OuPath")


#Delete Workstation from AD (MAKE SURE YOU HAVE THE RIGHT COMPUTER OBJECT):
([adsi]"$(([adsisearcher]"(samaccountname=$MachineName$)").findone().path)").deletetree()


#Command to use for PowerShell script in SCCM Package:
"%Windir%\sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -Command .\Your-Scriptfilename.ps1

#Repair SCCM client:
$([wmiclass]"\\$f\root\ccm:sms_client").repairclient()
#view log C:\Windows\CCM\Logs\CcmRepair.log

#Get collections a machine is a part of
(Get-WmiObject -ComputerName SCCMSiteServer -Namespace "root\SMS\site_XXX" -query "SELECT SMS_Collection.* FROM SMS_FullCollectionMembership, SMS_Collection where name = '$machine' and SMS_FullCollectionMembership.CollectionID = SMS_Collection.CollectionID").Name

#Get unique values after sorting by date
$f = $f | sort -property date -descending | group property1, property2 | %{$_.group | select * -first 1}

#Get all computers in AD:
$Searcher = [adsisearcher]"(objectcategory=Computer)"
$Searcher.pagesize = 1000
$Computers = $Searcher.findall().properties

#Get hash of String: 
(get-filehash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]"StringValue")) -Algorithm SHA1).hash


#Get windows event logs matching a specific ID (Using FilterHashTable is the fasted way to retrieve logs, which is necessary for pulling logs from a remote computer)
Get-WinEvent -FilterHashTable @{LogName="System"; Id="6006"; StartTime=$((get-date).adddays(-14))}


#Adding parameters to PowerShell scripts for Tanium
# In the Tanium Sensor builder, add a Parameter for each Parameter set below. Set the Delimiter in the Sensor Builder as it is set below.
# When executed on the client, Tanium will auto search/replace specified Parameters within this script before calling it.
# Tanium will encode Parameter strings, so ensure you unencode it in this script; see UnescapeDataString() below.

# Set parameters and unencode parameter strings passed in from Tanium
[cmdletbinding()]
param(
[string] $Variable = [System.Uri]::UnescapeDataString('||parameter_name||')
)

# For checkbox parameters, you don't need to unescape the parameter. Tanium's input is 0 or 1. For integer inputs like this, replace the string unescape line above with the following:
[int] $Variable = ('||parameter_name||')
