#!/bin/bash
tracepath "$1" | grep -oE '^ *[0-9]+:' | tail -n 1 | cut -d: -f1
