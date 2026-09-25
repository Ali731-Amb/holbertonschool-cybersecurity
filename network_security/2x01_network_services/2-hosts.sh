#!/bin/bash
grep -w "localhost" /etc/hosts | grep -v ":" | awk '{print $1}' | head -n1
