
param (
    [int]$debug = 1,
    [string]$OutputFileLocation = "$env:windir\temp\DCU_Prep_$(get-date -f yyyy.MM.dd-H.m).log",
    [string]$BIOSPassword = "Welcome1$"
)

# Environmentvariables:
# Path to .exe files. 
$DellCommandUpdateFolder = "C:\Program Files\Dell\CommandUpdate"
$DellCommandConfigureFolder = "C:\Program Files (x86)\Dell\Command Configure\X86_64"
$DellCommandUpdateExePath = "$DellCommandUpdateFolder\dcu-cli.exe"
$DellCommandConfigureExePath = "$DellCommandConfigureFolder\cctk.exe"

<#
 ---- Exit Codes ----
 These are the codes for Dell Command | Update
     0 = "Successfully patched this system."
     1 = "Reboot requiered"
     2 = "Fatal error during patch-process - Check $($env:Temp) for log files."
     3 = "Error during patch-process - Check $($env:Temp) for log files."
     4 = "Dell Update Command detected an invalid system and stopped."
     5 = "Reboot and scan required."

 Define some custom exit-codes for this script.
 11000 = "This script ran not on a Dell system - exited without any action"
 11001 = "Dell Command | Update software not found - exited without any action"
 11002 = "Dell Command | Update software found but .exe could not be found in defined Path $DellCommandUpdateExePath"
 11003 = "Dell Command | Configure software not found - exited without any action"
 11004 = "Dell Command | Configure software found but .exe could not be found in defined Path $DellCommandConfigureExePath"
 11005 = "BIOS is password protected but this script got the wrong password. Exiting now without actions."
 11006 = "Bitlocker is activated and could not be paused."
 11007 = "Dell Command Update could not import settings-xml-file"
 11008 = "Dell Command Update could not import reset-xml-file"
 11010 = "Unknown result of Dell Command | Update patching."
 11020 = "Could not re-set the BIOS-password. Please check the client!"
#>

# ----------------------------------------------------------------- Debugging -------------------------------------------------------------
# Enable debugging (1) or disable (0)
# Powershelldebugging:
Set-PSDebug -Trace 0
# Enable Debug-Write-Host-Messages:
$DebugMessages = $debug
#
# Send all Write-Host messages to console and to the file defined in $OutputFileLocation
if ($DebugMessages -eq "1") {
    # Stop transcript - just in case it's running in another PS-Script:
    $ErrorActionPreference="SilentlyContinue"
    Stop-Transcript | out-null
    # Start transcript of all output into a file:
    $ErrorActionPreference = "Continue"
    Start-Transcript -path $OutputFileLocation -append
}


# --------------------------------------------------------------- Functions --------------------------------------------------------------
# End this script with message and errorlevel
# call this function with "debugmsg errormessage errorlevel" 
# e.g.: debugmsg 2 "The cake is a lie"
function debugmsg($exitcode, $msg) {
    # Define var $ecode as script-wide so it can be modified by other functions.
    $script:ecode = $exitcode
    debugmsg $msg
    #resetSettings
    if ($DebugMessages -eq "1") {Stop-Transcript}
    debugmsg "Exiting with code $ecode"
    exit $ecode
}

# This function is just for better readability of this script
# Call it to print output to console and logfile
# e.g.: debugmsg "The variable xyz contains: $($CheckBIOSPassword.ExitCode)"
function debugmsg($dmsg) {
    if ($DebugMessages -eq "1") {Write-Host "$(get-date -f yyyy.MM.dd_H:m:s) - $dmsg"}
}



# ------------------------------------------------------- End definition of environment ---------------------------------------------------

# -------------------------------------------------------- Check for Dell-environment -----------------------------------------------------

# Check if this is a Dell system:
if (Get-WmiObject win32_SystemEnclosure -Filter: "Manufacturer LIKE 'Dell Inc.'") { 
    $isDellSystem = $true
    debugmsg "This system is identified as Dell-system."
    } else { 
    $manufacturer = $(Get-WmiObject win32_SystemEnclosure | Select-Object Manufacturer)
    debugmsg 11000 "This system could not be identified as Dell system - Found manufacturer: $manufacturer" 
}

# Check if the Dell Command | Update command-line exe-file exists:
if (Test-Path $DellCommandUpdateExePath) {
    $foundDellCommandUpdateExe = $true
} else {
    debugmsg 11002 "Dell Command | Update software found but .exe could not be found in defined Path $DellCommandUpdateExePath"
}


# Check if Dell Command | Update is running already and kill it:
$checkForDCU = Get-Process dcu-cli.exe -ErrorAction SilentlyContinue
if ( $checkForDCU -ne $null ) {
    debugmsg "dcu-cli.exe is already running - Killing it."
    Get-Process dcu-cli.exe | Stop-Process
}


# -------------------------------------------------------- Check security-settings --------------------------------------------------------

# Check if Bitlocker is enabled on Systemdrive:
$BLinfo = Get-Bitlockervolume -MountPoint $env:SystemDrive 
$bitlockerStatus=$($BLinfo.ProtectionStatus)

# --------------------------------------------------------------- Tasks -------------------------------------------------------------------
# Pause bitlocker if enabled
if( $bitlockerStatus -eq "On") {
    debugmsg "Bitlocker is activated - pausing it until next reboot."
    #$BLpause = Start-Process $env:SystemDrive\Windows\System32\manage-bde.exe -wait -PassThru -ArgumentList "-protectors -disable $env:SystemDrive"
   Suspend-BitLocker -MountPoint "C:" -RebootCount 1 -Verbose
#    $bitlockerPause = $($BLpause.ExitCode)
#        if( $bitlockerPause -eq 0) {
#            debugmsg "Bitlocker paused successfully"
#            } else {
#            debugmsg 11006 "Bitlocker is activated and could not be paused."
#            }
}



# Start patching
Get-Service -name 'DellClientManagementService' | Stop-Service -Verbose
debugmsg "Starting Patchprocess silently. Logging into $env:Temp\Dell_Command_Update_Patchlogs_$(get-date -f yyyy.MM.dd_H-m)"
$DCU_category = "firmware,driver"  # bios,firmware,driver,application,others
$DCUPatching=Start-Process $DellCommandUpdateExePath -ArgumentList "/applyUpdates -autoSuspendBitLocker=enable -reboot=disable -updateType=$DCU_category -outputLog=$env:windir\temp\DCU_Patchlogs_$(get-date -f yyyy.MM.dd_H-m).log" -Wait -Passthru -Verbose

# Interpret the returncode of patching-process:
switch ( $DCUPatching.ExitCode ) {
    0 {
        debugmsg 0 "Successfully patched this system."
    }
    1 { 
        debugmsg 1 "Successfully patched this system. Reboot requiered."
    }
    2 {
        debugmsg 2 "Fatal error during patch-process - Check $($env:Temp) for log files."
    }
    3 {
        debugmsg 3 "Error during patch-process - Check $($env:Temp) for log files."
    }
    4 {
        debugmsg 4 "Dell Update Command detected an invalid system and stopped."
    }
    5 {
        debugmsg 5 "Successfully patched this system. Reboot and scan required."
    }
}

debugmsg 11010 "Unknown result of Dell Command | Update patching."
Stop-Transcript
