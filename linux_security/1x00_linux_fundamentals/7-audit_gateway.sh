#!/bin/bash
cat << 'EOF' > /usr/local/bin/audit-read-secret
#!/bin/bash
cat /var/www/html/secret_config.php
EOF
chmod 755 /usr/local/bin/audit-read-secret
chown root:root /usr/local/bin/audit-read-secret
echo "$1 ALL=(root) NOPASSWD: /usr/local/bin/audit-read-secret" > /etc/sudoers.d/audit
chmod 440 /etc/sudoers.d/audit
