#!/bin/bash
m=$(( (0xFFFFFFFF << (32-$1)) & 0xFFFFFFFF )); printf "%d.%d.%d.%d\n" $((m>>24&255)) $((m>>16&255)) $((m>>8&255)) $((m&255))
