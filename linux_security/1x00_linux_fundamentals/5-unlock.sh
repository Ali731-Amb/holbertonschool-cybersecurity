#!/bin/bash
chattr -i "$1" && find "$1" -delete 2> /dev/null
