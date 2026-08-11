#!/bin/bash
. sentinel.conf
check_integrity() {
    for file in "${FILES_TO_WATCH[@]}"; do
        gold="/var/backups/sentinel/$(basename "$file").gold"
        hash1=$(md5sum "$file" | awk '{print $1}')
        hash2=$(md5sum "$gold" | awk '{print $1}')
        if [ "$hash1" = "$hash2" ]; then
            echo "OK: $file integrity verified"
        else
            cp "$gold" "$file"; echo "FIXED: Restored $file"
        fi
    done
}
check_integrity
