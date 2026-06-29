#!/usr/bin/env python3
#
# update-pihole-dns.py — sync Pi-hole's upstream DNS servers with the host's.
#
# WHAT THIS DOES:
#   Asks NetworkManager (via nmcli) which DNS servers the host's ethernet/wifi
#   connections are currently using, then rewrites the "upstreams" list in
#   Pi-hole's pihole.toml so Pi-hole forwards queries to those same servers.
#   This keeps Pi-hole working as the network's DNS changes (e.g. a laptop
#   moving between networks). It is invoked automatically by the NetworkManager
#   dispatcher hook installed by initial-setup.sh.
#
# HOW TO RUN:
#   ./update-pihole-dns.py        (or it runs automatically on network changes)
#   Note: it does NOT restart Pi-hole; Pi-hole/FTL picks up pihole.toml changes
#   on its own, or on its next reload.
#
# PREREQUISITES:
#   - NetworkManager + the `nmcli` command available.
#   - Pi-hole's pihole.toml at the path set in __main__ below; the process must
#     have permission to write it.

import subprocess
import re

def get_dns_servers():
    """Extract DNS servers from ethernet and wifi interfaces using nmcli"""
    # Run "nmcli device show" and capture its text output. check=True makes
    # Python raise an exception if nmcli exits non-zero, so failures are loud.
    result = subprocess.run(
        ['nmcli', 'device', 'show'],
        capture_output=True,
        text=True,
        check=True
    )

    # Split the captured output into individual lines to scan one at a time.
    lines = result.stdout.split('\n')
    # Collected DNS server IPs, in order, with duplicates removed.
    dns_servers = []
    # Tracks the type of the device whose section we're currently reading.
    # nmcli prints each device as a block of "KEY: value" lines.
    device_type = None

    for line in lines:
        # A "GENERAL.TYPE:" line marks the start of a device's block and tells
        # us what kind of device it is (ethernet, wifi, loopback, etc.). Remember
        # it so the DNS lines that follow can be filtered by device type.
        if 'GENERAL.TYPE:' in line:
            device_type = line.split(':')[1].strip()

        # Lines like "IP4.DNS[1]: 192.168.1.1" hold a DNS server. Only keep them
        # if the current device is a real ethernet or wifi link (ignore VPNs,
        # loopback, bridges, etc.).
        if 'IP4.DNS' in line and device_type in ['ethernet', 'wifi']:
            # Split on the FIRST colon only (maxsplit=1) so an IPv-style value
            # isn't chopped up; take the part after the colon and trim spaces.
            # Extract IP after the colon
            dns_ip = line.split(':', 1)[1].strip()
            # Skip blanks and avoid adding the same server twice.
            if dns_ip and dns_ip not in dns_servers:
                dns_servers.append(dns_ip)

    return dns_servers

def update_pihole_toml(filepath, dns_servers):
    """Update the upstreams array in pihole.toml"""
    # Read the whole config file into one string so we can search/replace it.
    with open(filepath, 'r') as f:
        content = f.read()

    # Build the replacement TOML array. We wrap each server IP in quotes and
    # join them with comma + newline + indent so the result is valid, readable
    # TOML, e.g.:  upstreams = [\n    "1.1.1.1",\n    "8.8.8.8"\n  ]
    # Build the new upstreams array
    dns_entries = ',\n    '.join(f'"{dns}"' for dns in dns_servers)
    new_upstreams = f'upstreams = [\n    {dns_entries}\n  ]'

    # Regex that matches the existing upstreams array. Breakdown:
    #   upstreams\s*=\s*\[   -> the literal key, "=", and opening bracket (with
    #                           optional whitespace around the "=")
    #   [^\]]*               -> any characters that are NOT a closing bracket
    #   \]                   -> the closing bracket
    # So it captures the entire "upstreams = [ ... ]" block, which re.sub then
    # swaps out for our freshly built array. NOTE: this assumes the array has no
    # ']' inside it (true for a simple list of quoted IPs).
    # Replace the upstreams array (everything between upstreams = [ and ])
    pattern = r'upstreams\s*=\s*\[[^\]]*\]'
    updated_content = re.sub(pattern, new_upstreams, content)

    # Write the modified config back out, overwriting the file.
    with open(filepath, 'w') as f:
        f.write(updated_content)

    # Report what we did so the run leaves a useful trail (e.g. in NM logs).
    print(f"Updated {filepath} with DNS servers:")
    for dns in dns_servers:
        print(f"  - {dns}")

# This block runs only when the file is executed directly (not when imported).
if __name__ == '__main__':
    # Discover the current upstream DNS servers from NetworkManager.
    dns_servers = get_dns_servers()

    # If we found none, there's nothing to write — bail out with a non-zero
    # exit code so callers (cron / the NM hook) can tell it failed.
    if not dns_servers:
        print("No DNS servers found for ethernet or wifi interfaces")
        exit(1)

    # Path to Pi-hole's config file (the etc-pihole bind-mount on the host).
    # Change this if your Pi-hole stores pihole.toml elsewhere.
    pihole_toml = '/home/j/pihole/etc-pihole/pihole.toml'  # Adjust path as needed
    update_pihole_toml(pihole_toml, dns_servers)
