#!/bin/bash
scp skeleton.conf 2-panic.sh engineer@10.97.0.150:~ && ssh engineer@10.97.0.150 "sudo /home/engineer/2-panic.sh && sudo nft -f /home/engineer/skeleton.conf && sudo nft list ruleset"
