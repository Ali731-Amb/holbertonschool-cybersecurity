#!/bin/bash
tshark -r "$1" -Y 'tcp contains "uid=0" || tcp contains "root"' -T fields -e tcp.dstport | sort | uniq -c | sort -rn | awk '{print $2}' | head -1
