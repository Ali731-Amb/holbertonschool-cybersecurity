#!/bin/bash
if ! dpkg -l "$1" 2>/dev/null | grep -q "^ii"; then
	apt-get install -y "$1"
fi
if grep -q "pam_pwquality.so" "$2"; then
	sed -i -E 's/(pam_pwquality\.so.*)/\1 minlen=12 minclass=3/' "$2"
else
	sed -i '1i password requisite pam_pwquality.so retry=3 minlen=12 minclass=3' "$2"
fi
