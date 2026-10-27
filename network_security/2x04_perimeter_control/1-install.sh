#!/bin/bash
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install nftables wireguard wireguard-tools && systemctl enable nftables
