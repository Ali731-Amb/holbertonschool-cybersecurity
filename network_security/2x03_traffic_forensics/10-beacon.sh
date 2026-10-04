#!/bin/bash
tshark -r "$1" -Y 'ip.src == 10.10.10.50 && ip.addr == 198.51.100.23' -T fields -e frame.time_relative
