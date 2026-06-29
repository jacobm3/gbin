# ============================================================================
# cf-dns.ps1 — point every network adapter at Cloudflare's filtering DNS
# ============================================================================
#
# WHAT THIS DOES
#   Sets the DNS servers on ALL of this machine's network interfaces to
#   Cloudflare's "1.1.1.1 for Families" servers, which block malware and adult
#   content at the DNS level (a bad domain simply fails to resolve). Before
#   changing anything it sanity-checks that the chosen DNS servers actually
#   answer queries, so a typo or an unreachable server can't leave you with no
#   working DNS.
#
# HOW TO RUN
#   Open an *Administrator* PowerShell (changing DNS needs admin rights), then:
#       powershell -ExecutionPolicy Bypass -File .\cf-dns.ps1
#   Often wired into a scheduled task so DNS stays locked to Cloudflare.
#
# PREREQUISITES
#   - Windows with the NetTSO / DnsClient PowerShell modules (built in to
#     Windows 8/Server 2012 and later) for Get-NetAdapter / Set-DnsClientServerAddress.
#   - Administrator privileges.
#
# Reference: https://blog.cloudflare.com/introducing-1-1-1-1-for-families/
# ============================================================================

# Apply CloudFlare DNS malware and adult content blocking to every interface
# https://blog.cloudflare.com/introducing-1-1-1-1-for-families/

# Get-NetAdapter returns one object per network adapter (Ethernet, Wi-Fi, etc).
# We loop over these later to change DNS on each one.
$interfaces = Get-NetAdapter

# Cloudflare DNS servers, block malware
# This array is assigned but immediately overwritten by the next assignment
# below, so it has no effect — it's left here as documentation of the
# "malware only" option. The "@( ... )" syntax creates a PowerShell array.
$dnsServers = @("1.1.1.2","1.0.0.2","2606:4700:4700::1112","2606:4700:4700::1002")

# Cloudflare DNS servers, block malware and adult content
# This is the array that actually gets used (it overwrites the one above).
# Two IPv4 addresses (1.1.1.3 / 1.0.0.3) plus their IPv6 equivalents.
$dnsServers = @("1.1.1.3", "1.0.0.3", "2606:4700:4700::1113", "2606:4700:4700::1003")

# Function to test DNS server by sending a DNS query request
# Returns $true only if EVERY server in the list successfully resolves a known
# domain. We call this before touching the system so we never point the machine
# at a DNS server that turns out to be dead.
function Test-DnsServerQuery {
    # param() declares the function's inputs. [string[]] means "array of strings".
    param (
        [string[]]$dnsServers
    )

    # A well-known domain we expect any working DNS server to resolve.
    $testDomain = "google.com"

    # Try each server in turn. If any one fails, we bail out with $false.
    foreach ($server in $dnsServers) {
        # try/catch: run the query, and jump to catch{} if it throws an error.
        try {
            # Resolve-DnsName is PowerShell's "nslookup". -Server forces the
            # query at this specific server. -ErrorAction Stop turns a failed
            # lookup into a catchable error instead of a silent warning.
            $result = Resolve-DnsName -Name $testDomain -Server $server -ErrorAction Stop
            # Extra guard: a server that answered but returned nothing useful.
            if (-not $result) {
                Write-Host "DNS server $server did not respond to the query for $testDomain."
                return $false
            }
        } catch {
            # The lookup threw (timeout, refused, unreachable, etc).
            Write-Host "Failed to query $testDomain on DNS server $server."
            return $false
        }
    }

    # Reached only if every server answered successfully.
    return $true
}

# Test DNS server query
# Run the health check above before changing any system settings.
$areDnsServersResponsive = Test-DnsServerQuery -dnsServers $dnsServers

# Only rewrite DNS settings if all the servers passed the health check.
if ($areDnsServersResponsive) {
    # Apply the same DNS server list to every adapter we found earlier.
    foreach ($interface in $interfaces) {
        # .Name is the friendly adapter name, e.g. "Ethernet" or "Wi-Fi".
        $interfaceName = $interface.Name

        Write-Host "Setting DNS servers for interface: $interfaceName"

        # Set-DnsClientServerAddress writes the static DNS server list for this
        # adapter. -InterfaceAlias selects the adapter by its friendly name.
        Set-DnsClientServerAddress -InterfaceAlias $interfaceName -ServerAddresses $dnsServers
    }

    # Note: "$dnsServers -join ','" inside a string is NOT evaluated here — only
    # $dnsServers expands, so this prints the array followed by the literal text
    # " -join ','". Cosmetic only; the DNS change above already happened.
    Write-Host "DNS servers set to Cloudflare's servers ($dnsServers -join ',') for all network interfaces."
} else {
    # At least one server failed the probe — leave DNS untouched to be safe.
    Write-Host "One or more of the DNS servers did not respond to the DNS query. DNS settings not changed."
}
