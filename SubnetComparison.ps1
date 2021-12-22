<#

Author: Curtis Powers
Intent: Compare subnets between two tools to determine if maximum coverage exists and where the gaps lie

#>





Function Convert-IPv4AddressToBinaryString {
  Param(
    [IPAddress]$IPAddress='0.0.0.0'
  )
  $addressBytes=$IPAddress.GetAddressBytes()

  $strBuilder=New-Object -TypeName Text.StringBuilder
  foreach($byte in $addressBytes){
    $8bitString=[Convert]::ToString($byte,2).PadRight(8,'0')
    [void]$strBuilder.Append($8bitString)
  }
  Write-Output $strBuilder.ToString()
}

Function ConvertIPv4ToInt {
  [CmdletBinding()]
  Param(
    [String]$IPv4Address
  )
  Try{
    $ipAddress=[IPAddress]::Parse($IPv4Address)

    $bytes=$ipAddress.GetAddressBytes()
    [Array]::Reverse($bytes)

    [System.BitConverter]::ToUInt32($bytes,0)
  }Catch{
    Write-Error -Exception $_.Exception `
      -Category $_.CategoryInfo.Category
  }
}

Function ConvertIntToIPv4 {
  [CmdletBinding()]
  Param(
    [uint32]$Integer
  )
  Try{
    $bytes=[System.BitConverter]::GetBytes($Integer)
    [Array]::Reverse($bytes)
    ([IPAddress]($bytes)).ToString()
  }Catch{
    Write-Error -Exception $_.Exception `
      -Category $_.CategoryInfo.Category
  }
}

Function Add-IntToIPv4Address {
  Param(
    [String]$IPv4Address,

    [int64]$Integer
  )
  Try{
    $ipInt=ConvertIPv4ToInt -IPv4Address $IPv4Address `
      -ErrorAction Stop
    $ipInt+=$Integer

    ConvertIntToIPv4 -Integer $ipInt
  }Catch{
    Write-Error -Exception $_.Exception `
      -Category $_.CategoryInfo.Category
  }
}

Function CIDRToNetMask {
  [CmdletBinding()]
  Param(
    [ValidateRange(0,32)]
    [int16]$PrefixLength=0
  )
  $bitString=('1' * $PrefixLength).PadRight(32,'0')

  $strBuilder=New-Object -TypeName Text.StringBuilder

  for($i=0;$i -lt 32;$i+=8){
    $8bitString=$bitString.Substring($i,8)
    [void]$strBuilder.Append("$([Convert]::ToInt32($8bitString,2)).")
  }

  $strBuilder.ToString().TrimEnd('.')
}

Function NetMaskToCIDR {
  [CmdletBinding()]
  Param(
    [String]$SubnetMask='255.255.255.0'
  )
  $byteRegex='^(0|128|192|224|240|248|252|254|255)$'
  $invalidMaskMsg="Invalid SubnetMask specified [$SubnetMask]"
  Try{
    $netMaskIP=[IPAddress]$SubnetMask
    $addressBytes=$netMaskIP.GetAddressBytes()

    $strBuilder=New-Object -TypeName Text.StringBuilder

    $lastByte=255
    foreach($byte in $addressBytes){

      # Validate byte matches net mask value
      if($byte -notmatch $byteRegex){
        Write-Error -Message $invalidMaskMsg `
          -Category InvalidArgument `
          -ErrorAction Stop
      }elseif($lastByte -ne 255 -and $byte -gt 0){
        Write-Error -Message $invalidMaskMsg `
          -Category InvalidArgument `
          -ErrorAction Stop
      }

      [void]$strBuilder.Append([Convert]::ToString($byte,2))
      $lastByte=$byte
    }

    ($strBuilder.ToString().TrimEnd('0')).Length
  }Catch{
    Write-Error -Exception $_.Exception `
      -Category $_.CategoryInfo.Category
  }
}

Function Get-IPv4Subnet {
  [CmdletBinding(DefaultParameterSetName='PrefixLength')]
  Param(
    [Parameter(Mandatory=$true,Position=0)]
    [IPAddress]$IPAddress,

    [Parameter(Position=1,ParameterSetName='PrefixLength')]
    [Int16]$PrefixLength=24,

    [Parameter(Position=1,ParameterSetName='SubnetMask')]
    [IPAddress]$SubnetMask
  )
  Begin{}
  Process{
    Try{
      if($PSCmdlet.ParameterSetName -eq 'SubnetMask'){
        $PrefixLength=NetMaskToCidr -SubnetMask $SubnetMask `
          -ErrorAction Stop
      }else{
        $SubnetMask=CIDRToNetMask -PrefixLength $PrefixLength `
          -ErrorAction Stop
      }
      
      $netMaskInt=ConvertIPv4ToInt -IPv4Address $SubnetMask     
      $ipInt=ConvertIPv4ToInt -IPv4Address $IPAddress
      
      $networkID=ConvertIntToIPv4 -Integer ($netMaskInt -band $ipInt)

      $maxHosts=[math]::Pow(2,(32-$PrefixLength)) - 2
      $broadcast=Add-IntToIPv4Address -IPv4Address $networkID `
        -Integer ($maxHosts+1)

      $firstIP=Add-IntToIPv4Address -IPv4Address $networkID -Integer 1
      $lastIP=Add-IntToIPv4Address -IPv4Address $broadcast -Integer -1

      if($PrefixLength -eq 32){
        $broadcast=$networkID
        $firstIP=$null
        $lastIP=$null
        $maxHosts=0
      }

      $outputObject=New-Object -TypeName PSObject 

      $memberParam=@{
        InputObject=$outputObject;
        MemberType='NoteProperty';
        Force=$true;
      }
      Add-Member @memberParam -Name CidrID -Value "$networkID/$PrefixLength"
      Add-Member @memberParam -Name NetworkID -Value $networkID
      Add-Member @memberParam -Name SubnetMask -Value $SubnetMask
      Add-Member @memberParam -Name PrefixLength -Value $PrefixLength
      Add-Member @memberParam -Name HostCount -Value $maxHosts
      Add-Member @memberParam -Name FirstHostIP -Value $firstIP
      Add-Member @memberParam -Name LastHostIP -Value $lastIP
      Add-Member @memberParam -Name Broadcast -Value $broadcast

      Write-Output $outputObject
    }Catch{
      Write-Error -Exception $_.Exception `
        -Category $_.CategoryInfo.Category
    }
  }
  End{}
}

<#-----------------------------------------------------------------------------


The start of the script that was written by me


-----------------------------------------------------------------------------#>

function Compare-Subnets {


	Param(
	
		[Parameter(
			Mandatory=$True
		)][String[]]$ActiveDirectory,
		[Parameter(
			Mandatory=$True
		)][String[]]$Nexpose,
		[Parameter(
			Mandatory=$True
		)][String[]]$NexposeSites
	
	)

	#Creates dictionary for ActiveDirectorySubnets
	$ActiveDirectorySubnets = @{}

	#Adds information about ActiveDirectory subnets into a dictionary (Subnet ID is the key, other details are the values in an array)
	foreach($line in $ActiveDirectory){

		$ipinfo = Get-IPv4Subnet -IPAddress $line.split("/")[0] -PrefixLength $line.split("/")[1]
		$subid = $ipinfo.networkID
		$bid = $ipinfo.Broadcast
		
		
		$SubInfo = [PSCustomObject]@{
			BroadcastID = $bid
			prefix = $ipinfo.PrefixLength
			mask = $ipinfo.SubnetMask
			hostcount = $ipinfo.HostCount
			ToolName = "Active Directory"
		}

		
		$ActiveDirectorySubnets.add([ipaddress]$subid, $SubInfo)

	}

	$NexposeSubnets = @{}

	#Adds information about Nexpose subnets into a dictionary (Subnet ID is the key, other details are the values in an array)
	foreach($line in $Nexpose){

		$ipinfo = Get-IPv4Subnet -IPAddress $line.split("/")[0] -PrefixLength $line.split("/")[1]
		$subid = $ipinfo.networkID
		$bid = $ipinfo.Broadcast
		
		
		$SubInfo = [PSCustomObject]@{
			BroadcastID = $bid
			prefix = $ipinfo.PrefixLength
			mask = $ipinfo.SubnetMask
			hostcount = $ipinfo.HostCount
			ToolName = "Nexpose"
		}
		
		$NexposeSubnets.add([ipaddress]$subid, $SubInfo)

	}



	$SubArray = @()
	
	#Compares both dictionaries together, creates a PowerShell custom object with the variables in the first part of the loop, and adds them to an array

	foreach($ADkey in $ActiveDirectorySubnets.keys){

		$SubnetId = $ADkey.IPAddresstoString
		$BroadcastId = $ActiveDirectorySubnets[$ADkey].BroadcastID
		$SubnetPrefix = $ActiveDirectorySubnets[$ADkey].prefix
		$SubnetMask = $ActiveDirectorySubnets[$ADkey].mask
		$ToolName = $ActiveDirectorySubnets[$ADkey].ToolName
		$HostCount = $ActiveDirectorySubnets[$ADkey].HostCount
		$inActiveDirectory = 'True'
		$inNexpose = 'False'
		$HostDiff = $null
		$Nested = 'False'
		$NestedSubnet = ''
		$NestedBroadcast = ''
		$IncludedSites = ''
		
		#checks to see if the subnet is configured in Nexpose
		if($NexposeSubnets[$ADkey]){
			
			$inNexpose = 'True'
			$IncludedSites = $NexposeSites.where{$_.included_networks -match "$($ADkey.IPAddresstoString)/$($ActiveDirectorySubnets[$ADkey].prefix)"}.name -join "`n"
			#Compares the host counts of the subnets to determine if the subnets are the same size. If not the same size, subtracts Nexpose from ActiveDirectory (negative denotes that Nexpose has more hosts)
			if($NexposeSubnets[$ADkey].hostcount -eq $ActiveDirectorySubnets[$ADkey].hostcount){
				$HostDiff = 0
			}else{
				$HostDiff = $ActiveDirectorySubnets[$ADkey].hostcount - $NexposeSubnets[$ADkey].hostcount
			}
		
		}else{
			#Loops through all the keys in the Nexpose Subnets to determine if the ActiveDirectory subnet is between the subnet ID and the Broadcast ID for every key in Nexpose
			#Stores each item (Nexpose subnet ID, AD Subnet, and Nexpose Broadcast ID) to an array of integers
			#Then loops through array of integers to compare them all to each other (Nexpose Subnet ID <= AD Subnet <= Nexpose Broadcast ID)
			#Creates a array of True False values, all values must be true for a subnet to be nested
			foreach($Nkey in $NexposeSubnets.keys){
				$SubtoInt = $Nkey.IPAddresstoString.split(".") | %{[int]$_}
				$AddrtoInt = $ADkey.IPAddresstoString.split(".") | %{[int]$_}
				$BrodtoInt = $NexposeSubnets[$Nkey].BroadcastID.split(".") | %{[int]$_}
				
				$Results = for($i = 0; $i -lt $AddrtoInt.count; $i++){$SubtoInt[$i] -le $AddrtoInt[$i] -and $AddrtoInt[$i] -le $BrodtoInt[$i]}
				
				if($arrResults -contains $false){
					#nothing
				}else{
					$inNexpose = 'True'
					$Nested = 'True'
					$NestedSubnet = $Nkey.IPAddresstoString
					$NestedBroadcast = $NexposeSubnets[$Nkey].BroadcastID
					$IncludedSites = $NexposeSites.where{$_.included_networks -match "$($ADkey.IPAddresstoString)/$($ActiveDirectorySubnets[$ADkey].prefix)"}.name -join "`n"
				}
			}
		
		}
		
		#stores all the information to a PowerShell custom object and adds it to the array of subnet information
		$SubInfo = [PSCustomObject]@{
			Subnet     = $SubnetId
			Broadcast = $BroadcastId
			Prefix = $SubnetPrefix
			Mask = $SubnetMask
			ToolName = $ToolName
			HostCount = $HostCount
			InActiveDirectory = $inActiveDirectory
			InNexpose = $inNexpose
			HostDiff = $HostDiff
			Nested = $Nested
			NestedSubnet = $NestedSubnet
			NestedBroadcast = $NestedBroadcast
			NexposeSites = $IncludedSites
		}
		
		$SubArray += $SubInfo

	}
	
	#Compares both dictionaries together, creates a PowerShell custom object with the variables in the first part of the loop, and adds them to an array
	foreach($Nkey in $NexposeSubnets.keys){

		$SubnetId = $Nkey.IPAddresstoString
		$BroadcastId = $NexposeSubnets[$Nkey].BroadcastID
		$SubnetPrefix = $NexposeSubnets[$Nkey].prefix
		$SubnetMask = $NexposeSubnets[$Nkey].mask
		$ToolName = $NexposeSubnets[$Nkey].ToolName
		$HostCount = $NexposeSubnets[$Nkey].HostCount
		$inNexpose = 'True'
		$inActiveDirectory = 'False'
		$HostDiff = $null
		$Nested = 'False'
		$NestedSubnet = ''
		$NestedBroadcast = ''
		$IncludedSites
		
		#checks to see if the subnet is configured in ActiveDirectory
		if($ActiveDirectorySubnets[$Nkey]){
			
			$inActiveDirectory = 'True'
			$IncludedSites = $NexposeSites.where{$_.included_networks -match "$($Nkey.IPAddresstoString)/$($NexposeSubnets[$Nkey].prefix)"}.name -join "`n"
			
			#Compares the host counts of the subnets to determine if the subnets are the same size. If not the same size, subtracts Nexpose from ActiveDirectory (negative denotes that Nexpose has more hosts)
			if($NexposeSubnets[$Nkey].hostcount -eq $ActiveDirectorySubnets[$Nkey].hostcount){
				$HostDiff = 0
			}else{
				$HostDiff = $NexposeSubnets[$Nkey].hostcount - $ActiveDirectorySubnets[$Nkey].hostcount
			}
		
		}else{
			
			#Loops through all the keys in the Nexpose Subnets to determine if the ActiveDirectory subnet is between the subnet ID and the Broadcast ID for every key in Nexpose
			#Stores each item (Nexpose subnet ID, AD Subnet, and Nexpose Broadcast ID) to an array of integers
			#Then loops through array of integers to compare them all to each other (Nexpose Subnet ID <= AD Subnet <= Nexpose Broadcast ID)
			#Creates a array of True False values, all values must be true for a subnet to be nested
			foreach($ADkey in $ActiveDirectorySubnets.keys){
				$SubtoInt = $ADkey.IPAddresstoString.split(".") | %{[int]$_}
				$AddrtoInt = $Nkey.IPAddresstoString.split(".") | %{[int]$_}
				$BrodtoInt = $ActiveDirectorySubnets[$ADkey].BroadcastID.split(".") | %{[int]$_}
				
				$Results = for($i = 0; $i -lt $AddrtoInt.count; $i++){$SubtoInt[$i] -le $AddrtoInt[$i] -and $AddrtoInt[$i] -le $BrodtoInt[$i]}
				
				if($Results -contains $false){
					#nothing
				}else{
					$inActiveDirectory = 'True'
					$Nested = 'True'
					$NestedSubnet = $ADkey.IPAddresstoString
					$NestedBroadcast = $ActiveDirectorySubnets[$ADkey].BroadcastID
					$IncludedSites = $NexposeSites.where{$_.included_networks -match "$($Nkey.IPAddresstoString)/$($NexposeSubnets[$Nkey].prefix)"}.name -join "`n"
				}
			}
		
		}
		
		#stores all the information to a PowerShell custom object and adds it to the array of subnet information
		$SubInfo = [PSCustomObject]@{
			Subnet     = $SubnetId
			Broadcast = $BroadcastId
			Prefix = $SubnetPrefix
			Mask = $SubnetMask
			ToolName = $ToolName
			HostCount = $HostCount
			InActiveDirectory = $inActiveDirectory
			InNexpose = $inNexpose
			HostDiff = $HostDiff
			Nested = $Nested
			NestedSubnet = $NestedSubnet
			NestedBroadcast = $NestedBroadcast
			NexposeSites = $IncludedSites
		}
		
		$SubArray += $SubInfo

	}

$SubArray

}

#Imports the files and runs the function
$NexposeSites = Import-csv 'nexpose_subnet_listing_2021-02-15.csv'
$Nexpose = cat 'NexposeSubnets.txt'
$ActiveDirectory = cat 'ADsubnets.txt'

$results = Compare-Subnets -ActiveDirectory $ActiveDirectory -Nexpose $Nexpose -NexposeSites $NexposeSites

$results | export-csv -NoTypeInformation -Path 'Comparison.csv'
