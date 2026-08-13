#!/bin/bash
# Deploy and activate the Sentinel security agent via systemd.
# Must be run as root.

set -e

# 1. Copy the unit files to the systemd system directory
cp sentinel.service /etc/systemd/system/
cp sentinel.timer /etc/systemd/system/

# 2. Reload systemd so it picks up the new unit files
systemctl daemon-reload

# 3. Enable the timer at boot and start it immediately
systemctl enable sentinel.timer
systemctl start sentinel.timer
