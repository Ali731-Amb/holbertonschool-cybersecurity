#!/bin/bash
mkdir -p "$1" && chown root:$2 "$1" && chmod 2770 $1
cat << 'EOF' > /etc/logrotate.d/app
/var/log/app/*.log {
    create 0640 root www-data
}
EOF
