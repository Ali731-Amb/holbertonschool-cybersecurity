#!/bin/bash
tshark -r "$1" -Y "urlencoded-form" -V | grep -oP 'Form item: "(password|pass|pwd)" = "\K[^"]*'
