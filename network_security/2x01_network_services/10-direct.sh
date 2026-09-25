#!/bin/bash
dig +short "@$1" "$2" A | grep -m1 "^[0-9]"
