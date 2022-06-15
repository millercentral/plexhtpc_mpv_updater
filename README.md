# plexhtpc_mpv_updater
PowerShell script to update Plex HTPC on Windows and also update to a newer mpv library

Features:
- Designed to run daily via Task Scheduler, grabs the latest Plex HTPC installed from plex.tv and verifies the download
- Grabs the latest mpv-2.dll from sourceforge (does not verify the download as my regex is not good enough to grab the SHA)
- Copies the files onto an existing Plex HTPC installation
- Stops and relaunches the Plex HTPC app if needed

Dumb Assumptions and Limitations:
- Requires Plex HTPC already be installed on the PC (doesn't do all the cool installer stuff)
- In my case, assumes Plex HTPC is installed in a non-priveleged folder (ie `C:\Plex HTPC\`) so script doesn't have to prompt for Elevated Access
- Requires a 7zip exe to extract the installer archive. I am using NanaZip from the Windows Store
- I'm running with PowerShell version 7. Don't know what version it actually requires
- Limited testing, limited error trapping. It will probably break / not work at some point.
- This is my first attempt at writing a PowerShell script. Expect bad code.
- Don't use this. But if you do, validate all the local paths defined in the script and update to your environment
- If you do use this. Disable auto updates in the `%USERPROFILE%\AppData\Local\Plex HTPC\plex.ini` file by adding: disableUpdater=true to the "[debug]" section.
