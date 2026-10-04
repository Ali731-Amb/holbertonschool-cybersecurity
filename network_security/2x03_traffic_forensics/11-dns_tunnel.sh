#!/bin/bash
tshark -r "$1" -T fields -e dns.qry.name | awk 'length > 50'
