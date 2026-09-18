#!/bin/bash
grep -m1 "^nameserver" /etc/resolv.conf | awk '{print $2}'
