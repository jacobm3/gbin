# ============================================================================
# usb-disable-power-mgmt.ps1
# ----------------------------------------------------------------------------
# Turns OFF the "Allow the computer to turn off this device to save power"
# checkbox for every USB device on the machine. Windows otherwise suspends idle
# USB controllers/hubs to save power, which can cause flaky USB peripherals
# (keyboards, mice, audio interfaces, DACs) to drop out or stutter. Disabling
# it makes USB devices stay reliably powered.
#
# This pokes the same setting you'd otherwise toggle by hand in Device Manager
# under each device's Properties -> Power Management tab.
#
# HOW TO RUN: open an *Administrator* PowerShell (writing these WMI settings
#   needs admin) and run:
#       powershell -ExecutionPolicy Bypass -File .\usb-disable-power-mgmt.ps1
#
# PREREQUISITES: admin rights. The settings persist across reboots.
# ============================================================================

# Get every USB device's power-management setting object.
#   Get-CimInstance queries WMI (Windows' device/management database).
#   - MSPower_DeviceEnable is the WMI class that holds the per-device
#     "allow turning this off to save power" flag.
#   - -Namespace root/WMI is where that class lives.
# The pipe "|" then filters to only the USB devices:
#   Where-Object keeps objects whose InstanceName starts with "USB"
#   (-Like with the * wildcard means "begins with USB").
$powerMgmt = Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace root/WMI |
    Where-Object InstanceName -Like USB*

# Loop over each matching USB device and clear its power-saving flag.
foreach ($p in $powerMgmt) {
    # .Enable = $false means "do NOT allow Windows to power this device down".
    # (Counterintuitive: Enable refers to the power-saving feature, so false
    # = power management disabled = device stays powered.)
    $p.Enable = $false
    # Write the modified object back to WMI so the change actually takes effect.
    Set-CimInstance -InputObject $p
}
