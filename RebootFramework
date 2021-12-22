<#

Author: Curtis Powers
Intent: Provide a framework for creating a package in SCCM or Tanium to persist through multiple reboots
Changes: 

#>

<#----------------------------------------------------------------------------------

	This script is a framework to use when needing to create a package for a configuration management tool (such as Tanium, SCCM) that requires multiple restarts for the entire process to finish. 
  
  The script uses PowerShell workflows (which store the results of a script to the hard drive rather than just memory) to allow the script to persist through multiple reboots. 
  The script is then kicked off again by using scheduled tasks for Windows under the system context to allow everything to happen in the background. 
  
  IMPORTANT NOTE:
  There is a possibility that this script will cause a never ending reboot loop for systems. 
  Rigorous testing is required if this will be used in an enterprise environment as the potential to put all machines this is deployed to in a reboot loop is high. 
  

----------------------------------------------------------------------------------#>




<#----------------------------------------------------------------------------------

	DEFINE THE FUNCTIONS NEEDED FOR THE SCRIPT AND THE WORKFLOW

----------------------------------------------------------------------------------#>

function Continue-Workflow {

	[CmdletBinding()]
	param([String]$JobName)

	$ModuleImported = [boolean](Get-Module -Name PSWorkflow)
	if(!$ModuleImported){
		Import-Module PSWorkflow
	}
	Get-Job -Name $JobName | Resume-Job | wait-job

}

function Cleanup-Workflow {

	[CmdletBinding()]
	param([String]$JobName, [String]$TaskName)
	
	$ModuleImported = [boolean](Get-Module -Name PSWorkflow)
	if(!$ModuleImported){
		Import-Module PSWorkflow
	}
	
	if($JobName){
		Get-Job -Name $JobName | Remove-Job -Force -ErrorAction SilentlyContinue
	}
	
	if($TaskName){
		Unregister-ScheduledTask -TaskName $TaskName -Confirm:$False
	}

}

function Create-WorkflowScheduledTask{

	param (
		[Parameter(Mandatory=$True)][String]$ScriptFile,
		[Parameter(Mandatory=$True)][String]$TaskName
	)
	
	$TaskDescription = "A Scheduled Task to continue the workflow that is saved to the disk"
	
	$Action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
	-Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $ScriptFile"

	$Trigger = New-ScheduledTaskTrigger -AtStartup
	
	Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName $TaskName -Description $TaskDescription -RunLevel Highest -User "System"

}

function Write-Log {

	param([String]$Content, [String]$LogPath)
	
	echo "$(get-date -format "yyyy/MM/dd-hh:mm:ss")-$Content" | Out-File -FilePath $LogPath -Append
	
}


workflow Invoke-WorkflowScript {

	<#----------------------------------------------------------------------------------
	
		CREATE THE SCRIPTFILE PARAMETER NEEDED FOR THE WORKFLOW TO CREATE THE SCHEDULED TASK
	
	----------------------------------------------------------------------------------#>
	
	
	param (
		[Parameter(Mandatory=$True)][String]$ScriptFile,
		[Parameter(Mandatory=$True)][String]$WorkflowLog,
		[Parameter(Mandatory=$True)][String]$ScriptPath,
		[Parameter(Mandatory=$True)][String]$TaskName
	)
	
	
	
	
	<#----------------------------------------------------------------------------------
	
		THE BODY OF THE WORKFLOW
	
	----------------------------------------------------------------------------------#>
	
	
	
	#put the content of whatever is needed in here
	
	Suspend-Workflow
	
	#put the rest of the content in here
	
	#the workflow has finished
		
}

<#----------------------------------------------------------------------------------

	DECLARE ALL VARIABLES TO BE USED IN THE SCRIPT AND IMPORT MODULES

----------------------------------------------------------------------------------#>
Import-Module PSWorkFlow

$JobName = "RunWorkflow-$((get-filehash -Path  $PSCommandPath -Algorithm SHA1).hash)"

$JobStatus = try{Get-Job -Name $JobName -erroraction Stop}catch [System.Management.Automation.PSArgumentException] {$False}

$SccmLogPath = "$env:SystemDrive\Windows\sccm_logs"

$WorkflowLog = "$SccmLogPath\WorkflowLog-$($PSCommandPath.split("\.")[-2]).txt"

<#----------------------------------------------------------------------------------

	BODY OF THE SCRIPT

----------------------------------------------------------------------------------#>

if(!(Test-Path -Path $SccmLogPath)){
	
	New-Item -Path $SccmLogPath -ItemType Directory -Force

}

if(!$JobStatus){

	Write-Log -Content "Workflow has not been started, creating the workflow now" -LogPath $WorkflowLog
	Invoke-WorkflowScript -AsJob -JobName $JobName -ScriptFile $PSCommandPath -WorkflowLog $WorkflowLog -ScriptPath $PSScriptRoot -TaskName $JobName | Wait-Job
	Write-Log -Content "Workflow has suspended, restarting the computer" -LogPath $WorkflowLog
	Restart-Computer -Force
	
}elseif($JobStatus.State -eq "Suspended"){
	
	Write-Log -Content "Workflow is suspended, continuing the workflow" -LogPath $WorkflowLog
	Continue-Workflow -JobName $JobName
	Write-Log -Content "Workflow has suspended or completed, restarting the computer" -LogPath $WorkflowLog
	Restart-Computer -Force
	
}elseif($JobStatus.State -eq "Completed"){
	
	Write-Log -Content "Workflow is completed, removing the workflow jobs and the scheduled tasks" -LogPath $WorkflowLog
	Cleanup-Workflow -JobName $JobName -TaskName $JobName
	
}
