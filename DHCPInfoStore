<#

Author: Curtis Powers
Intent: Create an offline file full of historical DHCP information for comparison with Vulnerability Scanners to track endpoints using DHCP without host names recorded
Changes: 

#>

$logpath = ""
$CsvPath = ""
#get a list of all DHCP servers
$DhcpServers = (get-dhcpserverindc).dnsname
if($?){echo "$(get-date -format "yyyyMMdd-hh,mm,ss")-Successfully queried DHCP servers" >> $logpath}


#get a list of all the scopes in the DHCP servers and save it into a Hashtable
#create the hashtable
$DhcpServersandScopes = @{}

foreach($DhcpServer in $DhcpServers){
	
	$DhcpServersandScopes.add($DhcpServer, @(get-dhcpserverv4scope -ComputerName $DhcpServer))

}

if($?){echo "$(get-date -format "yyyyMMdd-hh,mm,ss")-Queried all scopes and stuff" >> $logpath}


#get the leases that are a part of all those scopes
#$LeaseInfo = @()
foreach($DhcpServer in $DhcpServers){

	$Scopes = $DhcpServersandScopes.$DhcpServer.scopeid.ipaddresstostring
	foreach($Scope in $Scopes){
		$temp = get-dhcpserverv4lease -computername $DhcpServer -scopeid $Scope | where{$_.AddressState -eq "Active"}
		if($temp){
			$LeaseInfo += $temp | select *, @{name="LeaseStartTime";e={$_.LeaseExpiryTime.add(-($DhcpServersandScopes.$DhcpServer.where{$_.ScopeId -eq $Scope}.LeaseDuration))}}, @{Name="DHCPServer";e={$DHCPServer}}
		}
	}

}
if($LeaseInfo){echo "$(get-date -format "yyyyMMdd-hh,mm,ss")-Queried all DHCP lease info" >> $logpath}

#import the CSV of the historical file, and add the new info to it
if(test-path $CsvPath){
	$LeaseInfo += Import-CSV $CsvPath
}

#sort LeaseInfo based on LeaseExpiryTime
$LeaseInfo = $LeaseInfo | sort -property LeaseExpiryTime -Descending

#get the unique values for based on leaseexpirytime, ipaddress, and hostname
$LeaseInfo = $LeaseInfo | group IPAddress, Hostname, LeaseExpiryTime | %{$_.group | select * -first 1}

$LeaseInfo | export-csv $CsvPath -NoTypeInformation -force

if($?){echo "$(get-date -format "yyyyMMdd-hh,mm,ss")-successfully completed LeaseInfo Query at $(get-date)" >> $logpath}

$error | export-csv "\\watercooler\home\powerscd\Scripts\DHCPInfo\errors.csv" -notypeinformation
