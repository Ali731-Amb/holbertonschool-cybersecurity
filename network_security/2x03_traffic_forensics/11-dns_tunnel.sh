#!/bin/bash
tshark -r "$1" -Y 'len(dns.qry.name) > 50' -T fields -e dns.qry.name
