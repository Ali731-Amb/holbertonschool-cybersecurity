#!/bin/bash
IFS=. read -r a b c d <<< "$1"; IFS=. read -r e f g h <<< "$2"; printf "%d.%d.%d.%d" $(( (a & e) | (~e & 255) )) $(( (b & f) | (~f & 255) )) $(( (c & g) | (~g & 255))) $(( (d & h) | (~h & 255)))
