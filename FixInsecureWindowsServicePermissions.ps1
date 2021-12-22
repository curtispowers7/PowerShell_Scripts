<#

Author: Curtis Powers
Intent: Resolves the vulnerability associated with Tenable plugin 65057
https://www.tenable.com/plugins/nessus/65057

#>

#Retrieves and returns all the paths to the executables that are installed services by querying WMI
function Get-ServiceExecutables {

	$Services = Get-WmiObject -Class win32_service
	$ServicePaths = $Services.PathName

	foreach($ServicePath in $ServicePaths){
	
		if($ServicePath -match "^[^ `"].+\.[a-z]{3}$"){
			$ServicePath
		}elseif($ServicePath -match "^`".+$"){
			($ServicePath -split "`"")[1]
		}elseif($ServicePath -match "^(.+\.\S{3})( |$)"){
			$matches[0]
		}

	}
	

}

#Writes a string passed to the function to a log
function Write-Log {

	param([String]$Content, [String]$LogPath)
	
	echo "$(get-date -format "yyyy/MM/dd-hh:mm:ss")-$Content" | Out-File -FilePath $LogPath -Append
	
}

#Removes write permissions from the IdentityReference passed to the function and creates a new ACL with read and execute permissions for all groups except "Everyone"
function Remediate-VulnerablePermissions {

	param([String]$tmpPath, [String]$IdentityReference)
	
	$acl = Get-Acl -Path $tmpPath

	$acl.setaccessruleprotection($true, $true)
	$acl | Set-Acl -Path $tmpPath
	$acl = Get-Acl -Path $tmpPath
	$acl.access.where{$_.IdentityReference -eq "$IdentityReference"} | %{$acl.removeaccessrule($_)} | out-null
	$acl.access.where{$_.IdentityReference -eq "$IdentityReference"} | %{$acl.removeaccessrule($_)} | out-null
	if($IdentityReference -ne "Everyone"){
		$rule = new-object System.Security.AccessControl.FileSystemAccessRule("$IdentityReference", "ReadAndExecute", "Allow")
		$acl.addaccessrule($rule)
	}
	$acl | Set-Acl -path $tmpPath
	

}


#Initiate the variables
$ServiceExecutables = Get-ServiceExecutables | Sort -Unique
$VulnerablePerms = @("FullControl", "Modify")

$SccmLogPath = "$env:SystemDrive\Windows\sccm_logs"
$LogFile = "$SccmLogPath\InsecureWindowsServicePermissions-Remediation.txt"

if(!(Test-Path -Path $SccmLogPath)){
	
	New-Item -Path $SccmLogPath -ItemType Directory -Force

}

#Loops through all the steps in the path for all the service executables and compares them to the list of vulnerable permissions. If the permissions are vulnerable, then writes to the log and remediates them by calling Remediate-VulnerablePermissions
foreach($ServiceExecutable in $ServiceExecutables){
	
	$tmpPath = ""

	foreach($path in ($ServiceExecutable -split "(?<=\\)")){ #splits the windows path into chunks (C:\windows\system32 -> ['C:\', 'windows\', 'system32'])
	
		$tmpPath += $path
		
		$acl = try{Get-Acl -Path $tmpPath -ErrorAction Stop} catch {$False}
		
		foreach($IdentityReference in ($acl.Access.identityreference | Select -ExpandProperty Value | Sort -Unique)){
		
			$Permissions = ""
		
			switch ($IdentityReference){
			
				"Everyone" {
					$Permissions = (($acl.Access | where{$_.IdentityReference -eq "$IdentityReference"}).filesystemrights -split ",").trim() | where {$_ -in $VulnerablePerms}
					if($Permissions){
						Write-Log -Content "$ServiceExecutable has vulnerable permissions at path $tmpPath with Identity of $IdentityReference with permissions of $($Permissions -join ";"), remediating the permissions now" -LogPath $LogFile
						Remediate-VulnerablePermissions -tmpPath $tmpPath -IdentityReference $IdentityReference
					}
				}
				
				"BUILTIN\Users" {
					$Permissions = (($acl.Access | where{$_.IdentityReference -eq "$IdentityReference"}).filesystemrights -split ",").trim() | where {$_ -in $VulnerablePerms}
					if($Permissions){
						Write-Log -Content "$ServiceExecutable has vulnerable permissions at path $tmpPath with Identity of $IdentityReference with permissions of $($Permissions -join ";"), remediating the permissions now" -LogPath $LogFile
						Remediate-VulnerablePermissions -tmpPath $tmpPath -IdentityReference $IdentityReference
					}
				}
				
				"NT AUTHORITY\Authenticated Users" {
					$Permissions = (($acl.Access | where{$_.IdentityReference -eq "$IdentityReference"}).filesystemrights -split ",").trim() | where {$_ -in $VulnerablePerms}
					if($Permissions){
						Write-Log -Content "$ServiceExecutable has vulnerable permissions at path $tmpPath with Identity of $IdentityReference with permissions of $($Permissions -join ";"), remediating the permissions now" -LogPath $LogFile
						Remediate-VulnerablePermissions -tmpPath $tmpPath -IdentityReference $IdentityReference
					}
				}
				
				"DS\Domain Users" {
					$Permissions = (($acl.Access | where{$_.IdentityReference -eq "$IdentityReference"}).filesystemrights -split ",").trim() | where {$_ -in $VulnerablePerms}
					if($Permissions){
						Write-Log -Content "$ServiceExecutable has vulnerable permissions at path $tmpPath with Identity of $IdentityReference with permissions of $($Permissions -join ";"), remediating the permissions now" -LogPath $LogFile
						Remediate-VulnerablePermissions -tmpPath $tmpPath -IdentityReference $IdentityReference
					}
				}
			
			}
		}
	}

}
