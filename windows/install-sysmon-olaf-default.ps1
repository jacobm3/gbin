# ============================================================================
# install-sysmon-olaf-default.ps1
# ----------------------------------------------------------------------------
# Installs (or reconfigures) Sysinternals Sysmon using Olaf Hartong's widely
# used "sysmon-modular" default configuration. Sysmon is a Windows monitoring
# driver/service that records detailed security events (process creation,
# network connections, file and registry changes) to the Windows Event Log,
# which is invaluable for incident response and threat hunting.
#
# This is the readable, multi-line version of
# "install-sysmon-olaf-default-one-liner.ps1" — same behavior, easier to read.
#
# HOW TO RUN: open an *Administrator* PowerShell (a kernel driver install needs
#   admin rights) and run:
#       powershell -ExecutionPolicy Bypass -File .\install-sysmon-olaf-default.ps1
#   The -accepteula flags auto-accept the Sysinternals license.
#
# PREREQUISITES: admin rights and internet access to download.sysinternals.com
#   and raw.githubusercontent.com.
# ============================================================================

# Force the HTTP client to use TLS 1.2. Older Windows/PowerShell defaults to
# TLS 1.0, which the Sysinternals and GitHub servers reject — without this line
# the downloads below can fail with a "could not create SSL/TLS channel" error.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; 

# Path to save the Sysmon download. $env:TEMP is the current user's temp folder.
$zip = "$env:TEMP\Sysmon.zip"; 

# Download the Sysmon zip from Sysinternals into the path above.
# Invoke-WebRequest is PowerShell's built-in "wget"/"curl".
Invoke-WebRequest "https://download.sysinternals.com/files/Sysmon.zip" -OutFile $zip; 

# Unzip into %TEMP%\SysmonFolder. -Force overwrites if it already exists.
Expand-Archive -LiteralPath $zip -DestinationPath $env:TEMP\SysmonFolder -Force; 

# Path to save the configuration file we download next.
$config = "$env:TEMP\sysmonconfig.xml"; 

# Download Olaf Hartong's default sysmon-modular config. This XML tells Sysmon
# which events to log and which noisy ones to filter out — it's the brains of
# the install; without it Sysmon logs very little.
Invoke-WebRequest "https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml" -OutFile $config; 

# Build the full path to the freshly-extracted Sysmon64.exe. Join-Path safely
# combines a folder and filename with the right backslash in between.
$exe = Join-Path $env:TEMP\SysmonFolder "Sysmon64.exe"; 

# Decide between "update config" and "fresh install":
# Get-Command checks whether Sysmon64.exe already lives in C:\Windows
# ($env:SystemRoot), which is where Sysmon installs itself. -ErrorAction
# SilentlyContinue means "don't error if it's missing, just return nothing".
if (Get-Command "$env:SystemRoot\Sysmon64.exe" -ErrorAction SilentlyContinue) { 
    # Already installed: "-c" pushes the new config to the running service.
    # "&" is PowerShell's call operator — it runs the program at that path.
    & "$env:SystemRoot\Sysmon64.exe" -accepteula -c $config 
} else { 
    # Not installed yet: "-i" installs the driver/service WITH this config.
    & $exe -accepteula -i $config 
}
