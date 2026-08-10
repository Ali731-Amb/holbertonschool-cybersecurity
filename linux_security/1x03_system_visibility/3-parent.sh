#!/bin/bash
ps -o ppid -p $1 | awk 'NR==2 {print $1}'
