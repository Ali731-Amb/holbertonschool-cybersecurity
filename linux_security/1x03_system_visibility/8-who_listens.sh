#!/bin/bash
ss -lntp4 | grep ":$1" | awk -F'"' '{print $2}'
