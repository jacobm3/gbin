
# ============================================================================
# win10-lean.ps1 — strip Windows 10 down to a lean, fast workstation
# ============================================================================
#
# WHAT THIS DOES (original "v1"; see win10-lean-v2.ps1 for the newer version)
#   A semi-manual recipe to debloat and set up a fresh Windows 10 box. It:
#     1. Loosens system settings for speed (disables Defender real-time/behavior
#        monitoring, last-access timestamps, hibernation; AV folder exclusions;
#        disables background apps; allows local scripts to run).
#     2. Runs the Sycnex "Windows10Debloater" telemetry/bloat remover via a
#        piped one-liner (`iwr ... | iex`).
#     3. Disables a few optional services, removes bundled Microsoft apps with
#        winget, and installs the user's preferred apps.
#
# WARNING: this REDUCES SECURITY (disables Microsoft Defender real-time and
#   behavior monitoring). Only use where that tradeoff is acceptable.
#
# HOW TO RUN
#   Intended to be run in stages, not blindly top to bottom:
#     - Paste the "paste block" below into an *Administrator* PowerShell.
#     - Apply Windows Updates.
#     - Then run the rest. The top part is safe to rerun.
#
# PREREQUISITES: Windows 10, Administrator rights, internet access, winget.
# ============================================================================

# Paste this section into an admin powershell terminal
# Begin paste block
# Turn OFF Defender real-time (on-access) virus scanning. Faster disk I/O, but
# much weaker malware protection — a deliberate tradeoff for this machine.
Set-MpPreference -DisableRealtimeMonitoring $true
# Turn OFF Defender behavior monitoring (the heuristic malware-behavior engine).
Set-MpPreference -DisableBehaviorMonitoring $true
# Stop NTFS updating each file's last-accessed timestamp on every read (cuts
# disk writes). "1" = the feature is disabled.
fsutil behavior set disablelastaccess 1
# Disable hibernation and delete the multi-GB C:\hiberfil.sys file.
powercfg.exe /hibernate off
# Exclude these program/build folders and the winget cache from Defender
# scanning so installs and builds run faster.
Add-MpPreference -ExclusionPath "C:\Windows","C:\Program Files","C:\Program Files (x86)","D:\Program Files","D:\Program Files (x86)","%TEMP%\WinGet"

# disable background apps
# Registry write: GlobalUserDisabled=1 is the master switch that stops UWP/Store
# apps running in the background (saves CPU/RAM/battery).
#   /v=value name  /t=REG_DWORD (32-bit number)  /d=data  /f=force, no prompt.
Reg Add HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications /v GlobalUserDisabled /t REG_DWORD /d 1 /f

# enable unsigned powershell scripts
# Set the script-execution policy to "RemoteSigned": local scripts run freely,
# internet-downloaded scripts must be signed. -Force skips the prompt.
# (Line duplicated below; rerunning it is harmless.)
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# End Paste Block

# apply win10 updates

# Then execute this entire script (ok to rerun the top part)

# Once that completes, run https://github.com/Sycnex/Windows10Debloater/blob/master/Windows10DebloaterGUI.ps1 to disable telemetry
# and perform other debloat techniques
# or:
# Download and immediately run the Sycnex debloater in one go:
#   iwr = Invoke-WebRequest, "-useb" = -UseBasicParsing (fetch raw text), and
#   "| iex" pipes that text into Invoke-Expression, which runs it as a script.
#   (Convenient but risky: it executes whatever that URL currently serves.)
iwr -useb https://git.io/debloat|iex

# Not needed by most individual end users
# Disable these services from starting at boot (unneeded on a single-user PC):
#   MapsBroker=Offline Maps, SharedAccess=Internet Connection Sharing,
#   LanmanServer=SMB file sharing host, edgeupdate/edgeupdatem=Edge auto-updaters.
Set-Service -Name MapsBroker -StartupType Disabled
Set-Service -Name SharedAccess -StartupType Disabled
Set-Service -Name LanmanServer -StartupType Disabled
Set-Service -Name edgeupdate -StartupType Disabled
Set-Service -Name edgeupdatem -StartupType Disabled


# UNINSTALLS
# Remove Microsoft's bundled/built-in apps with winget (the Windows Package
# Manager). "winget uninstall <name>" matches the package by name and removes
# it. This whole block strips out default Windows "bloat".
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
#   -i / --interactive : show the app's own installer GUI
#   --exact            : match the package id EXACTLY (no fuzzy matching)
#   --silent           : install with no prompts/UI
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
# https://pathcopycopy.github.io/       (extra app to consider installing)
# https://geeks3d.com/furmark/downloads/ (GPU stress-test tool to consider)
# disable background tasks

# scheduled task to start altsnap w/admin privs  (window-snapping helper at login)
# scheduled task to run c:\bin\cf-dns.ps1         (lock DNS to Cloudflare at login)
# make a system restore point                     (snapshot before all this surgery)
