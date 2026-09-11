#!/bin/bash
tracepath "$1" | awk '{print $1}' | cut -d: -f1
