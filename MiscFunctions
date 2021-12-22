#Parses an SCCM Log File and returns the results as an object for easier reviewing
Function Get-CMLog($path){

	#read the SCCM log file
	$SCCM_Log = Get-Content $path
	
	
	#Get all line numbers that start with [log] and subtract from 1 to 
	$log_line_numbers = select-string -Pattern "\<\!\[LOG\[" -path $path | %{($_.tostring().split(":")[2]) - 1}
	
	for($i = 0; $i -le ($Log_line_numbers.count-1); $i++){
	
		
		If($i -eq ($log_line_numbers.count-1)){
			$log_entry = $SCCM_Log | select -index ($log_line_numbers[$i])
		}else{
			$log_entry = $SCCM_Log | select -Index ($Log_line_numbers[$i]..($Log_line_numbers[$i+1]-1))
		}
		#join the log entry on new line character to select all log text by itself
		$log_entry = $log_entry -join "`n"
		
		#Get the date and time to be one object itself and convert to DateTime object
		#get the time
		$time = $log_entry.split("<>")[3].split(" ")[0].split("`"")[1].split("+")[0]
		
		#get the date (could cause problems since different files have different formats for months and days (06 as opposed to 6 for June)
		$date = $log_entry.split("<>")[3].split(" ")[1].split("`"")[1]
		
		#convert to DateTime property using the appropriate format
		If($date -match "0[0-9]-0[0-9]-2019"){$date = [datetime]::parseexact(($date + " " + $time), "MM-dd-yyyy HH:mm:ss.fff", $null)}
		Else{$date = [datetime]::parseexact(($date + " " + $time), "M-d-yyyy HH:mm:ss.fff", $null)}
		
		New-Object -type PSObject -property @{
			#gather all the pieces of the log entry to add to the custom PSObject
			'Date' = $date
			'Log Name' = $log_entry.split("<>")[3].split(" ")[2].split("`"")[1]
			'Thread' = $log_entry.split("<>")[3].split(" ")[5].split("`"")[1]
			'Log Text' = $log_entry.split("<>")[1]
			'Context' = $log_entry.split("<>")[3].split(" ")[3].split("`"")[1]
			'Type' = $log_entry.split("<>")[3].split(" ")[4].split("`"")[1]
			'File' = $log_entry.split("<>")[3].split(" ")[6].split("`"")[1]
		}
		
	}

}





#This function is broken and doesn't return all the results. Need to expand the keys that it looks at for Windows Devices
function Get-InstalledApplications($strComputerName){


	$objReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', "$strComputerName")

	$strKey = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"

	$objRegKey = $objReg.opensubkey($strKey)
	
	if($objRegKey){

		$arrSubKeys = $objRegKey.getsubkeynames()

		foreach($strSubKey in $arrSubKeys){

			$objSubKey = $objRegKey.opensubkey($strSubKey)
			$objInstalledApplication = New-Object PSObject
			$objInstalledApplication | Add-Member -Name 'SoftwareName' -MemberType NoteProperty -Value $objSubKey.getvalue("DisplayName")
			$objInstalledApplication | Add-Member -Name 'SoftwareVersion' -MemberType NoteProperty -Value $objSubKey.getvalue("DisplayVersion")
			$objInstalledApplication | Add-Member -Name 'InstallLocation' -MemberType NoteProperty -Value $objSubKey.getvalue("InstallLocation")
			$objInstalledApplication | Add-Member -Name 'UninstallString' -MemberType NoteProperty -Value $objSubKey.getvalue("UninstallString")
			$objInstalledApplication | Add-Member -Name 'ArchitechtureType' -MemberType NoteProperty -Value "x64"
			$objInstalledApplication

		}
	}


	$strKey = 'HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

	$objRegKey = $objReg.opensubkey($strKey)
	if($objRegKey){

		$arrSubKeys = $objRegKey.getsubkeynames()

		foreach($strSubKey in $arrSubKeys){

			$objSubKey = $objRegKey.opensubkey($strSubKey)
			$objInstalledApplication = New-Object PSObject
			$objInstalledApplication | Add-Member -Name 'SoftwareName' -MemberType NoteProperty -Value $objSubKey.getvalue("DisplayName")
			$objInstalledApplication | Add-Member -Name 'SoftwareVersion' -MemberType NoteProperty -Value $objSubKey.getvalue("DisplayVersion")
			$objInstalledApplication | Add-Member -Name 'InstallLocation' -MemberType NoteProperty -Value $objSubKey.getvalue("InstallLocation")
			$objInstalledApplication | Add-Member -Name 'UninstallString' -MemberType NoteProperty -Value $objSubKey.getvalue("UninstallString")
			$objInstalledApplication | Add-Member -Name 'ArchitechtureType' -MemberType NoteProperty -Value "x86"
			$objInstalledApplication

		}
	}
}



#Pulls the headers from a web server and checks to see if "Strict-Transport-Security" is added into the headers, forcing a website to use HTTPS over HTTP
function Check-StrictTransportSecurity ($hostname, $port) {

	$u = "https://$($hostname):$($port)"
	
	try {
		$r = Invoke-WebRequest -uri $u
	}catch{
		$r = ""
	}
	
	if($r){
	
		$r.headers
		if($r.headers."Strict-Transport-Security"){
			echo "Thank you for providing the information needed to validate this finding is no longer an issue. I confirmed from the comment that the value of `"Strict-Transport-Security`" is $($r.headers."Strict-Transport-Security") has been added to the headers for $hostname."
		}else{
			echo "For the server in question, the following command was run: (Invoke-WebRequest -Uri `"https://$($hostname):$($port)`").headers. This should have resulted in a variable of Strict-Transport-Security with a value of max-age=31536000, however, this variable was not present. This was the result of the headers for that command: $(foreach($i in $r.headers.keys){echo "$i - $($r.headers.$i)"})"
		}
	}else{
		
		echo "no request"
	
	}

}



#Takes a downloaded HTML file of a Remedy ticket view and exports the tickets to a CSV file
function Export-RemedyTickets {

	Param(
		[Parameter(Mandatory=$true)]
		[String]
		$Path,
		[Parameter(Mandatory=$true)]
		[String]
		$HtmlFilePath
	)
	
	#import html file
	$HTML = New-Object -ComObject "HTMLFile"
	$HTML.IHTMLDocument2_write((get-content -Path $HtmlFilePath -raw))
	

	#Set all rows to an array
	$rows = $HTML.all.tags('div') | where{$_.classname -match "ng-scope ngRow (even|odd)"} 
	
	$Tickets = @()
	
	foreach($row in $rows){
		
		#Create a new custom object
		$tmpObject = [pscustomobject]@{
		
			WorkOrder = $row.getelementsbyclassname('ngCellText ng-scope col2 colt2') | %{$_.textcontent}
			Assignee = $row.getelementsbyclassname('ngCellText ng-scope col6 colt6') | %{$_.textcontent}
			Summary = $row.getelementsbyclassname('ngCellText ng-scope col7 colt7') | %{$_.textcontent}
			LastModifiedDate = $row.getelementsbyclassname('ngCellText ng-scope col9 colt9') | %{$_.textcontent}
		
		}
		
		
		#Add custom object with all information into empty array above
		$Tickets += $tmpObject
		
	}
	
	
	#Export the array of custom objects to a csv
	$Tickets | Export-Csv -Path $Path -NoTypeInformation
	

}

