#!/bin/bash
chattr -i "$1" && rm "$1" 2> /dev/null
