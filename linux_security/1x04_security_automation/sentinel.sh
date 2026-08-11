#!/bin/bash
[ -f sentinel.conf ] && . sentinel.conf && [ -n "$SERVICES" ] && [ -n "$FILES_TO_WATCH" ] || { echo "Error: config file is missing" >&2 ; exit 1 ;  }
