#!/bin/bash
lsof -i :$1 | grep ":$1" | awk -F'"' '{print $2}'
