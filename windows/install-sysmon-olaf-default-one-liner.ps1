# ============================================================================
# install-sysmon-olaf-default-one-liner.ps1
# ----------------------------------------------------------------------------
# Single-line installer for Sysinternals Sysmon using Olaf Hartong's popular
# "sysmon-modular" default config. Sysmon is a Windows system-monitoring driver
# that logs rich security telemetry (process creation, network connections,
# file/registry changes) to the Windows Event Log.
#
# WHAT THE ONE-LINER DOES, IN ORDER:
#   1. Force TLS 1.2 so the HTTPS downloads work on older Windows defaults.
#   2. Download Sysmon.zip from Sysinternals into %TEMP%.
#   3. Unzip it to %TEMP%\SysmonFolder.
#   4. Download Olaf Hartong's sysmonconfig.xml into %TEMP%.
#   5. If Sysmon is ALREADY installed (Sysmon64.exe in C:\Windows), just push
#      the new config with "-c". Otherwise install fresh with "-i".
#
# This file is deliberately kept as ONE line so it can be pasted straight into
# an elevated PowerShell prompt. The companion script
# "install-sysmon-olaf-default.ps1" is the identical logic split across lines
# with the same comments — read that one to understand each step.
#
# HOW TO RUN: paste into an *Administrator* PowerShell window (installing a
# kernel driver requires admin). Accepts the Sysinternals EULA via -accepteula.
# PREREQUISITES: admin rights + internet access to download.sysinternals.com
# and raw.githubusercontent.com.
# ============================================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $zip = "$env:TEMP\Sysmon.zip"; Invoke-WebRequest "https://download.sysinternals.com/files/Sysmon.zip" -OutFile $zip; Expand-Archive -LiteralPath $zip -DestinationPath $env:TEMP\SysmonFolder -Force; $config = "$env:TEMP\sysmonconfig.xml"; Invoke-WebRequest "https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml" -OutFile $config; $exe = Join-Path $env:TEMP\SysmonFolder "Sysmon64.exe"; if (Get-Command "$env:SystemRoot\Sysmon64.exe" -ErrorAction SilentlyContinue) { & "$env:SystemRoot\Sysmon64.exe" -accepteula -c $config } else { & $exe -accepteula -i $config }
