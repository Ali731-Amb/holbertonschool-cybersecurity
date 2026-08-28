#!/bin/bash
printf "%08d.%08d.%08d.%08d\n" $(echo "obase=2; ${1//./;}" | bc)
