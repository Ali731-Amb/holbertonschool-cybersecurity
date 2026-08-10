#!/bin/bash
ss -tln -4 | awk 'NR!=1 { print $4 }' | cut -d: -f2 | sort -n
