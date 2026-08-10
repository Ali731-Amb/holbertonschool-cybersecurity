#!/bin/bash
seuil=$(date -d "30 minutes ago" +%s)
grep -w "sshd" "$1" | while read -r ligne; do
    date_ligne=$(echo "$ligne" | awk '{print $1, $2, $3}')
    ts=$(date -d "$date_ligne" +%s)
    if [ "$ts" -ge "$seuil" ]; then
        echo "$ligne"
    fi
done
