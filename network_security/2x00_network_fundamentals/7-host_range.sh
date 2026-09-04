#!/bin/bash
IFS=. read -r a b c d <<< "$1"; m=$(( (0xFFFFFFFF << (32-$2)) & 0xFFFFFFFF )); e=$((m>>24&255)); f=$((m>>16&255)); g=$((m>>8&255)); h=$((m&255)); printf "%d.%d.%d.%d - %d.%d.%d.%d\n" $((a&e)) $((b&f)) $((c&g)) $(( (d&h)+1 )) $((a&e)) $((b&f)) $((c&g)) $(( ((d&h)|(~h&255))-1 ))
