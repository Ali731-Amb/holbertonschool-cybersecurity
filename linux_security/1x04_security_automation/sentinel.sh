#!/bin/bash
[ -f sentinel.conf ] && . sentinel.conf && [ -n "$SERVICES" ] || { echo "Error: config file is missing" >&2 ; exit 1 ;  }
