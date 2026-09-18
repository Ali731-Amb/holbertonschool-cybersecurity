#!/bin/bash
dig +short $1 | grep -m1 "^[0-9]" 
