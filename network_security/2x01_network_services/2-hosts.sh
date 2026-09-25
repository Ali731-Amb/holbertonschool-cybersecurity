#!/bin/bash
grep -w "localhost" /etc/hosts | grep -v ":" | head -n1 | awk '{printf "%s", $1}'
