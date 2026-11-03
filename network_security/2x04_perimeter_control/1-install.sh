#!/bin/bash
#embauche du gardien, mais pas tout de suite on attend 
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install nftables wireguard wireguard-tools && systemctl enable nftables
