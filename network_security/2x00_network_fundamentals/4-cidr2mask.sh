#!/bin/bash
b=$(printf '1%.0s' $(seq 1 $1); printf '0%.0s' $(seq 1 $((32-$1)))); printf "%d.%d.%d.%d\n" $(echo "ibase=2; ${b:0:8}; ${b:8:8}; ${b:16:8}; ${b:24:8}" | bc)
