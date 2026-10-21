#!/bin/bash
tshark -r "$1" -q --export-objects http,/tmp/carve_test && md5sum /tmp/carve_test/*
