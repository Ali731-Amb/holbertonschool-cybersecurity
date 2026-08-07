#!/bin/bash
while read -r username; do
	if id "$username" >/dev/null 2>&1;  then
    	passwd -l "$username" ; echo "User $username locked"
	else
    	echo "User $username not found"
	fi
done < "$1" 
