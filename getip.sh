#!/bin/sh
# script to get IP for a MAC address
mac=$(echo "$1" | sed -e 's/00/0/g')
eval $(grep -C2 "hw_address=.,$mac" /var/db/dhcpd_leases)
test -n "$lease" || exit 1
echo "$name has address $ip_address"
