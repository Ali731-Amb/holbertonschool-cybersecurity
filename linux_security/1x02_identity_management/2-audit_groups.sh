#!/bin/bash
awk -F: '$3 >= 1000 {print $1}' "$1" | while read user; do
	for grp in disk docker shadow; do
		if id -nG "$user" | grep -qw "$grp"; then
			echo "$user:$grp"
		fi
	done
done 
