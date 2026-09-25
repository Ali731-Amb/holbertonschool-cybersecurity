#!/bin/bash
grep "dhcp-server-identifier" /var/lib/dhcp/dhclient.leases | tail -n1 | awk '{print $3}' | tr -d ';'
