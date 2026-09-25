#!/bin/bash
grep "^127." /etc/hosts | awk '{print $1}'
