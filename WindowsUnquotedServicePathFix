<#

Author: Curtis Powers
Intent: Resolves the vulnerability associated with Tenable plugin 63155
https://www.tenable.com/plugins/nessus/63155

#>

#Sets the default path for installed services to a variable
$ServiceKeyPath = "HKLM:\SYSTEM\CurrentControlSet\services"

#Gets the list of service names as reported when using get-service in PowerShell
$ServiceNames = (Get-Item "$ServiceKeyPath\*").name | %{$_.split("\")[-1]}

#Matches the services that require fixes by searching for keys where the imagepath value has a space in it and no quotes
$KeysToFix = $ServiceNames | %{Get-ItemProperty -Path "$ServiceKeyPath\$_"} | Where{$_.imagepath -match "^.*\s.*\.[a-z]{3}$"}

#Matches the services that have been fixed previously either through manual remediation or a previous iteration of this script
$KeysFixed = $ServiceNames | %{Get-ItemProperty -Path "$ServiceKeyPath\$_"} | Where{$_.imagepath -match "^`"+.*\s.*\.[a-z]{3}`"+$"}

#Loops through all the keys and adds quotes to the imagepath value, remediating the vulnerability
foreach($Key in $KeysToFix){

	$ServicePath = $Key.ImagePath
	$KeyPath = "$ServiceKeyPath\$($Key.PSChildName)"
	
	New-ItemProperty -Path $KeyPath -Name "ImagePath" -Value "`"$ServicePath`"" -PropertyType ExpandString -Force | out-null

}
