### Plex HTPC Windows + Custom MPV Updater
### Version 0.0.1-061422
### This probable won't work.

function WriteLog {
    Param ([string]$logstring)
    $datestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logmessage = "[$datestamp] $logstring"
    Add-content $logfile -value $logmessage
}
# Todo: 
#  [] Add try-catch validation for web operations
#  [] Make sure web and file-sourced varibales are valid
#  [] Fix dumb coding (ongoing)

$logfile = "D:\plexhtpc_updater\plexhtpc_update.log"
# Reset the log file with each run
$null | Out-File -FilePath $logfile
$local_install_path = "C:\Plex HTPC\"
$local_version_file = "$env:USERPROFILE\AppData\Local\Plex HTPC\version.txt"
$temp_path = "$env:TEMP\plexhtpc_updater\"
$zip_tool = "nanazipc"

WriteLog "Starting"
# Get the latest Plex HTPC download information
$json = Invoke-WebRequest -Uri "https://plex.tv/api/downloads/7.json" | ConvertFrom-Json
$download = $json.computer.Windows.releases.url
$download_checksum = $json.computer.Windows.releases.checksum
$download_version = $json.computer.Windows.version.Substring(0,$json.computer.Windows.version.IndexOf("-"))
$download_filename = $download.Substring($download.LastIndexOf("/")+1)

WriteLog "Available Plex HTPC version: $download_version"
# Check that the available version is newer then the installed version

if (Test-Path -Path $local_version_file -PathType Leaf) {
    $local_version = Get-Content -Path $local_version_file
    WriteLog "Installed Plex Version: $local_version"
    if ([System.Version] $download_version -gt [System.Version] $local_version) {
        $is_new = "True"
    }
}
else {
    WriteLog "No local version file found. First time running update script?"
    # No local version file, assume download is newer
    New-Item -Path $local_version_file -ItemType "file"
    $is_new = "True"
}

if ($is_new -eq "True") {
    # download and validate plexhtpc update
    if (Test-Path -Path $temp_path)
    {
        WriteLog "Looks like an old version of the temp folder is here. Lets delete it"
        Remove-Item $temp_path -Recurse -Force
    }
    New-Item -Path $temp_path -ItemType Directory
    WriteLog "Downloading Plex Installer from [ $download ]"
    Invoke-WebRequest -Uri $download -OutFile ($temp_path + $download_filename)
    $file_hash = Get-FileHash ($temp_path + $download_filename) -Algorithm "SHA1"
    if ($download_checksum -ne $file_hash.Hash) {
        # File is bad, exit!
        WriteLog ("Plex Update hash did not match! Expected: [$download_checksum] Actual: [" + $file_hash.Hash +"]")
        WriteLog "Cleaning up temp directory"
        Remove-Item $temp_path -Recurse -Force
        Exit
    }
    WriteLog ("Plex Update hash matched! Expected: [$download_checksum] Actual: [" + $file_hash.Hash +"]")
    WriteLog "Calling $zip_tool to extract Plex HTPC install package"
    # Call ZipTool to extract the download (builtin zip library doesn't unpack nsis or 7z archives)
    $zip_params = @("x",($temp_path+$download_filename),("-o"+$temp_path+"app\"),"-y")
    & $zip_tool @zip_params
    
    # Go get the latest MPV-1 library
    # <TODO> All of this needs error trapping and validation
    $mpv_lib_webpage = Invoke-WebRequest -Uri "https://sourceforge.net/projects/mpv-player-windows/files/libmpv/"
    $mpv_download_url = [regex]::match($mpv_lib_webpage.Content, "https:\/\/sourceforge\.net\/projects\/mpv-player-windows\/files\/libmpv\/mpv-dev-x86_64.*\/download").Value
    $strstart = $mpv_download_url.IndexOf("/mpv-dev")+1
    $strlen = $mpv_download_url.IndexOf("/download") - $strstart
    $mpv_filename = $mpv_download_url.Substring($strstart,$strlen)
    WriteLog "mpv lib filename: [$mpv_filename]"
    # Use WebClient object since Invoke-WebRequest doesn't seem to follow SourceForge redirects correctly
    WriteLog "Downloading mpv library from [ $mpv_download_url ]"
    $webclient = New-Object System.Net.WebClient
    $webclient.DownloadFile($mpv_download_url, $temp_path + $mpv_filename)

    # My regex skills are not strong enough to capture the correct SHA1 value from the sourceforge webpage to 
    # validate the file is good, so for now we will have to assume it is.

    WriteLog "Calling $zip_tool to extract the mpv library archive"
    $zip_params = @("x",($temp_path+$mpv_filename),("-o"+$temp_path+"lib\"),"-y")
    & $zip_tool @zip_params

    # Okay, we have all the files, lets stop Plex HTPC if it is running, copy the files, then start it up again
    WriteLog "Stopping Plex HTPC if it running"
    $plexprocess = Get-Process "Plex HTPC" -ErrorAction SilentlyContinue
    if ($plexprocess) {
        # try to quit gracefully
        $plexprocess.CloseMainWindow()
        Start-Sleep -Seconds 5
        if (!$plexprocess.HasExited) {
            WriteLog "It didn't exit gracefully, forcing it closed"
            $plexprocess | Stop-Process -Force
        }
    }
    else {
        WriteLog "Plex HTPC wasn't running"
    }

    # First, copy the new files from the Plex Installer package, ignoring the installer specific junk
    WriteLog "Copying Plex HTPC installer files"
    Copy-Item -Path ($temp_path + "app\*") -Destination $local_install_path -Recurse -Exclude '$PLUGINSDIR', '$TEMP', "*.nsi", "*.nsis" -Force >> $logfile

    # Next copy and rename the updated mpv library
    WriteLog "Copying updated mpv lib"
    Copy-Item -Path ($temp_path + "lib\mpv-2.dll") -Destination ($local_install_path + "mpv-1.dll") -Force >> $logfile

    # Write out a local version file so we know what version is installed
    WriteLog "Saving version file for next run"
    $download_version | Out-File -FilePath $local_version_file -NoNewLine

    # Finally, lets clean up our temp directory
    WriteLog "Cleaning up temp directory"
    Remove-Item $temp_path -Recurse -Force

    # Restart Plex HTPC if it was running before
    if ($plexprocess) {
        WriteLog "Restarting Plex HTPC since it was running earlier"
        Start-Process -FilePath ($local_install_path + "Plex HTPC.exe")
    }
}
else {
    # update is not newer then current version, so don't do anything
    WriteLog "Online version of Plex HTPC is not newer than what is installed. Nothing to do."
}
