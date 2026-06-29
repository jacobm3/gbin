
# ============================================================================
# win10-lean-v2.ps1 — strip Windows 10 down to a lean, fast workstation
# ============================================================================
#
# WHAT THIS DOES
#   A semi-manual "debloat + setup" recipe for a fresh Windows 10 install. It:
#     1. Loosens a few system settings for speed (disables Defender real-time
#        scanning, last-access timestamps, hibernation; excludes big folders
#        from antivirus; disables background apps).
#     2. Downloads the Sycnex "Windows10Debloater" tool (for telemetry/bloat
#        removal) and then `exit`s — so by default ONLY the top section + the
#        debloater download run.
#     3. (Below the `exit`, intentionally not auto-run) disables optional
#        services, removes bundled Microsoft apps via winget, and installs the
#        user's preferred apps.
#
# WARNING: this REDUCES SECURITY (it disables Microsoft Defender real-time and
#   behavior monitoring). Only use on a machine where that's an accepted
#   tradeoff. This is "v2" of win10-lean.ps1.
#
# HOW TO RUN
#   This is meant to be run piecemeal, not blindly start-to-finish:
#     - Copy the "paste block" below into an *Administrator* PowerShell.
#     - Apply Windows Updates.
#     - Run the rest of the script; note the `exit` partway down stops
#       execution before the uninstall/install sections, which you then run
#       manually (or comment out the exit).
#
# PREREQUISITES: Windows 10, Administrator rights, internet access, and winget
#   (App Installer) for the uninstall/install sections.
# ============================================================================

#test

# Paste this section into an admin powershell terminal
# Begin paste block
# enable unsigned powershell scripts
# Set-ExecutionPolicy controls whether PowerShell will run scripts.
# "RemoteSigned" = locally-written scripts run freely; scripts downloaded from
# the internet must be code-signed. -Scope sets where the policy applies
# (LocalMachine = all users; CurrentUser = just you). -Force skips the prompt.
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Set-MpPreference tweaks Microsoft Defender antivirus settings.
# Turn OFF real-time (on-access) virus scanning. Speeds up disk-heavy work but
# leaves the machine far less protected — a deliberate tradeoff for this box.
Set-MpPreference -DisableRealtimeMonitoring $true
# Turn OFF behavior monitoring (the heuristic "is this acting like malware" engine).
Set-MpPreference -DisableBehaviorMonitoring $true
# fsutil tweaks low-level NTFS filesystem behavior.
# "disablelastaccess 1" stops Windows updating each file's last-accessed
# timestamp on every read, which cuts disk writes. (Line is duplicated below;
# running it twice is harmless.)
fsutil behavior set disablelastaccess 1
fsutil behavior set disablelastaccess 1
# Disable hibernation. This also deletes the multi-GB C:\hiberfil.sys file,
# reclaiming disk space (the size of your RAM).
powercfg.exe /hibernate off
# Tell Defender to skip scanning these folders entirely (program/build dirs and
# the winget download cache), so installs and builds run faster.
Add-MpPreference -ExclusionPath "C:\Windows","C:\Program Files","C:\Program Files (x86)","D:\Program Files","D:\Program Files (x86)","%TEMP%\WinGet"

# disable background apps
# Reg Add writes a registry value. This one sets GlobalUserDisabled = 1 under
# the BackgroundAccessApplications key, the master switch that stops UWP/Store
# apps from running in the background (saves CPU/RAM/battery).
#   /v = value name, /t = type (REG_DWORD = 32-bit number),
#   /d = data, /f = force (no confirmation prompt).
Reg Add HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications /v GlobalUserDisabled /t REG_DWORD /d 1 /f

# End Paste Block

# apply win10 updates

# Then execute this entire script (ok to rerun the top part)

# Once that completes, run https://github.com/Sycnex/Windows10Debloater/blob/master/Windows10DebloaterGUI.ps1 to disable telemetry
# and perform other debloat techniques
# or:
# (the one-liner below pipes the remote debloat script straight into PowerShell;
#  left commented out — v2 downloads the repo to disk instead, see below)
#iwr -useb https://git.io/debloat|iex

# Define the URL of the repository's .zip file
$repoUrl = "https://github.com/Sycnex/Windows10Debloater/archive/master.zip"
# Define the destination where the .zip file will be saved
# $env:USERPROFILE is your home folder, e.g. C:\Users\Jacob.
$zipPath = "$env:USERPROFILE\Downloads\Windows10Debloater-master.zip"
# Define the folder to which the .zip file will be extracted
$extractPath = "$env:USERPROFILE\Downloads\Windows10Debloater-master"

# Download the .zip file from GitHub
Invoke-WebRequest -Uri $repoUrl -OutFile $zipPath

# Unblock the file in case it is marked as coming from the internet
# Windows tags internet downloads with a "Mark of the Web"; Unblock-File strips
# that tag so the extracted scripts run without security warnings.
Unblock-File -Path $zipPath

# Expand the .zip file
# Unzip the downloaded archive into $extractPath.
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath

# Cleanup the .zip file if you want
# Delete the now-extracted .zip to save space.
Remove-Item -Path $zipPath

# Stop the script here. Everything BELOW this line (service disables, app
# uninstalls, app installs) is intentionally NOT auto-run — review and run it
# by hand, or comment out this exit to let it all execute.
exit



# Not needed by most individual end users
# Set-Service ... -StartupType Disabled stops these Windows services from
# starting at boot. Each is unneeded on a single-user workstation:
#   MapsBroker   - Offline Maps downloads
#   SharedAccess - Internet Connection Sharing (turn this PC into a router)
#   LanmanServer - hosting SMB/Windows file shares from this PC
#   edgeupdate / edgeupdatem - Microsoft Edge's auto-updaters
Set-Service -Name MapsBroker -StartupType Disabled
Set-Service -Name SharedAccess -StartupType Disabled
Set-Service -Name LanmanServer -StartupType Disabled
Set-Service -Name edgeupdate -StartupType Disabled
Set-Service -Name edgeupdatem -StartupType Disabled


# UNINSTALLS
# Remove Microsoft's bundled/built-in apps using winget (the Windows Package
# Manager). "winget uninstall <name>" finds the matching package and removes it.
# This whole block strips out the default Windows "bloat" the user doesn't want.
winget uninstall "3D Viewer"
winget uninstall "Cortana"
winget uninstall "Disney+"
winget uninstall "Feedback Hub"
winget uninstall "Get Help"
winget uninstall "Groove Music"
winget uninstall "MSN Weather"
winget uninstall "Mail and Calendar"
winget uninstall "Microsoft Pay"
winget uninstall "Microsoft People"
winget uninstall "Microsoft Solitaire Collection"
winget uninstall "Microsoft Tips"
winget uninstall "Microsoft Update Health Tools"
winget uninstall "Microsoft.OneDrive"
winget uninstall "Microsoft.WindowsPCHealthCheck"
winget uninstall "Mixed Reality Portal"
winget uninstall "Movies & TV"
winget uninstall "Office"
winget uninstall "OneNote for Windows 10"
winget uninstall "Phone Link"
winget uninstall "Skype"
winget uninstall "Snip & Sketch"
winget uninstall "Store Experience Host"
winget uninstall "Windows Camera"
winget uninstall "Windows Maps"
winget uninstall "Windows Voice Recorder"
winget uninstall "Xbox Console Companion"
winget uninstall "Xbox Game Bar Plugin"
winget uninstall "Xbox Game Bar"
winget uninstall "Xbox Game Speech Window"
winget uninstall "Xbox Identity Provider"
winget uninstall "Xbox TCUI"
winget uninstall "Xbox"
winget uninstall "Your Phone"


# INSTALLS
# Install the user's preferred apps via winget. Flag reminders:
#   -i / --interactive : show the app's own installer GUI (lets you click through)
#   --exact            : match the package id EXACTLY (no fuzzy name matching)
#   --silent           : install with no prompts/UI at all
winget install -i "Microsoft.VisualStudioCode"
winget install --exact "Bitwarden.Bitwarden"
winget install --exact "mcmilk.7zip-zstd"
winget install --exact "AltSnap.AltSnap"
winget install --exact "Brave.Brave"
winget install --exact "CPUID.CPU-Z"
winget install --exact "CrystalDewWorld.CrystalDiskMark"
winget install --exact "FastStone.Viewer"
winget install --exact "GIMP.GIMP"
winget install --exact "Git.Git"
winget install --exact "Google.Chrome"
winget install --silent --exact "Greenshot.Greenshot"
winget install --exact "Notepad++.Notepad++"
winget install --exact "VideoLAN.VLC"
winget install --exact "AntibodySoftware.WizTree"
winget install --exact "RandyRants.SharpKeys"
winget install --exact "Ookla.Speedtest"
winget install --exact "Eraser.Eraser"
winget install --exact "TechPowerUp.GPU-Z"
winget install --exact "TheDocumentFoundation.LibreOffice"
winget install --exact "Zoom.Zoom"
winget install --exact "MiniTool.PartitionWizard.Free"
winget install "Microsoft.WindowsTerminal"

# --- manual follow-up reminders (TODO notes, not executable code) -----------
# configure greenshot settings
# https://pathcopycopy.github.io/      (extra app to consider installing)
# https://geeks3d.com/furmark/downloads/ (GPU stress-test tool to consider)
# disable background tasks

# scheduled task to start altsnap w/admin privs  (window-snapping helper at login)
# scheduled task to run c:\bin\cf-dns.ps1         (lock DNS to Cloudflare at login)
# make a system restore point                     (snapshot before all this surgery)
