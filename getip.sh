#!/bin/sh
# script to get IP for a MAC address
mac=$(echo "$1" | sed -e 's/00/0/g')
eval $(grep -C2 "hw_address=.,$mac" /var/db/dhcpd_leases)
if [ -z "$lease" ]; then
  ip_address=$(arp -an | grep "$mac" | cut -d' ' -f2 | tr -d '()')
  eval $(grep -B1 -A3 "ip_address=$ip_address" /var/db/dhcpd_leases)
fi
echo "$name has address $ip_address"
