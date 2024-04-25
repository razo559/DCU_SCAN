Start-Transcript -Path "C:\tmp\Dell_Command_Temp\DCU_Task_Reboot.log"
$Name = "Dell Command*"
$ProcName = "*Dell*"
$Timestamp = Get-Date -Format "yyyy-MM-dd_THHmmss" -Verbose
$LogFile = "c:\tmp\Dell_Command_Temp\DCU-Uninst_$Timestamp.log"
$ProgramList = @( "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" )
$Programs = Get-ItemProperty $ProgramList -EA 0 -Verbose
$App = ($Programs | Where-Object { $_.DisplayName -like $Name -and $_.UninstallString -like "*msiexec*" }).PSChildName
$TaskName = "DCU_Removal"

Get-Process | Where-Object { $_.ProcessName -like $ProcName } | Stop-Process -Force -Verbose

foreach ($GUID in $App) {
        $Params = @(
    "/passive"
    "/norestart"
    "/X"
    "$GUID"
    "/L*V ""$LogFile"""
    )
	Start-Process "msiexec.exe" -ArgumentList $Params -Wait -NoNewWindow -Verbose
}

if ($(Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue).TaskName -eq $TaskName) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$False -Verbose
}
#Get-ChildItem -Path "C:\tmp\Dell_Command_Temp" -Recurse | Remove-Item -Verbose -Confirm:$false

Stop-Transcript
