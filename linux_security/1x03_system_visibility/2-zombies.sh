#!/bin/bash
ps -eo pid,stat | awk '$2 ~ /Z/ {print $1}'
