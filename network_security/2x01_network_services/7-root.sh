#!/bin/bash
dig +trace "$1" | grep -m1 "Received.*root-servers" | awk '{print $6}' | cut -d'#' -f1
