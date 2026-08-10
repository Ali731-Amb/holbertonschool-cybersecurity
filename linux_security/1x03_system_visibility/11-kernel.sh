#!/bin/bash
[ -f /var/log/kern.log ] && grep "segfault" /var/log/kern.log; [ -f /var/log/messages ] && grep "segfault" /var/log/messages
