#!/usr/bin/env python3

import subprocess
import re

def get_dns_servers():
    """Extract DNS servers from ethernet and wifi interfaces using nmcli"""
    result = subprocess.run(
        ['nmcli', 'device', 'show'],
        capture_output=True,
        text=True,
        check=True
    )
    
    lines = result.stdout.split('\n')
    dns_servers = []
    device_type = None
    
    for line in lines:
        if 'GENERAL.TYPE:' in line:
            device_type = line.split(':')[1].strip()
        
        if 'IP4.DNS' in line and device_type in ['ethernet', 'wifi']:
            # Extract IP after the colon
            dns_ip = line.split(':', 1)[1].strip()
            if dns_ip and dns_ip not in dns_servers:
                dns_servers.append(dns_ip)
    
    return dns_servers

def update_pihole_toml(filepath, dns_servers):
    """Update the upstreams array in pihole.toml"""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Build the new upstreams array
    dns_entries = ',\n    '.join(f'"{dns}"' for dns in dns_servers)
    new_upstreams = f'upstreams = [\n    {dns_entries}\n  ]'
    
    # Replace the upstreams array (everything between upstreams = [ and ])
    pattern = r'upstreams\s*=\s*\[[^\]]*\]'
    updated_content = re.sub(pattern, new_upstreams, content)
    
    with open(filepath, 'w') as f:
        f.write(updated_content)
    
    print(f"Updated {filepath} with DNS servers:")
    for dns in dns_servers:
        print(f"  - {dns}")

if __name__ == '__main__':
    dns_servers = get_dns_servers()
    
    if not dns_servers:
        print("No DNS servers found for ethernet or wifi interfaces")
        exit(1)
    
    pihole_toml = '/home/j/pihole/etc-pihole/pihole.toml'  # Adjust path as needed
    update_pihole_toml(pihole_toml, dns_servers)
