#!/bin/bash
tshark -r "$1" -Y "http.response.code" | wc -l 
