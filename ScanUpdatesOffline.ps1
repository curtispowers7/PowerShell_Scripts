<#----------------------------------------------------------------

I'm not the author for this script, this comes straight from Microsoft. 
However, this is extremely useful for troubleshooting patch compliance for single machines that are of a high target (such as domain controllers). 

The wsusscn2.cab file can be found here:
https://docs.microsoft.com/en-us/windows/win32/wua_sdk/using-wua-to-scan-for-updates-offline

Download it by clicking on "Download Wsusscn2.cab" within the article.

----------------------------------------------------------------#>

$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
$UpdateService = $UpdateServiceManager.AddScanPackageService("Offline Sync Service", "C:\Users\cpowers\Downloads\wsusscn2.cab", 1)
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

$UpdateSearcher.ServerSelection = 3 #ssOthers

$UpdateSearcher.ServiceID = $UpdateService.ServiceID

$SearchResult = $UpdateSearcher.Search("IsInstalled=0")

$Updates = $SearchResult.Updates

$Updates | %{$_.Title}
