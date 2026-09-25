#!/bin/bash
grep "^127." /etc/localhost | awk '{print $1}'
