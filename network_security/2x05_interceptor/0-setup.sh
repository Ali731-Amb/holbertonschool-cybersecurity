#!/bin/bash
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install squid && systemctl enable squid 
[ -f /etc/squid/squid.conf.bak ] || cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
