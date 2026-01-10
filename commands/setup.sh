#!/usr/bin/env bash

if ! confirm 'Continue to setup server?'; then
	abort
fi

[[ -d /etc/nginx/http/ ]] || sudo mkdir -p /etc/nginx/http

nginx_conf=/etc/nginx/nginx.conf
if ! grep -q 'include http/\*.conf;' "$nginx_conf"; then
	sudo sed -i '/^http {/a \\t# Include http modules\n\tinclude http/*.conf;\n' "$nginx_conf"
	test_nginx
fi

#
# Install daily cron script for generating Cloudflare real IP config for NGINX.
#

cloudflare_real_ip=/etc/cron.daily/nginx-cloudflare-real-ip

root_write "$cloudflare_real_ip" <<'EOF'
#!/bin/bash

if ! ip4=$(curl -fsL https://www.cloudflare.com/ips-v4); then
	echo 'Failed to fetch Cloudflare IPv4 addresses' >&2
	exit 1
fi

if ! ip6=$(curl -fsL https://www.cloudflare.com/ips-v6); then
	echo 'Failed to fetch Cloudflare IPv6 addresses' >&2
	exit 1
fi

{
	for i in $ip4; do
		echo "set_real_ip_from $i;"
	done

	echo ''

	for i in $ip6; do
		echo "set_real_ip_from $i;"
	done

	echo ''
	echo 'real_ip_header CF-Connecting-IP;'
	echo ''
} > /etc/nginx/http/cloudflare-real-ip.conf

if ! nginx -t -q; then
	exit 1
fi

nginx -s reload &> /dev/null
EOF

sudo chmod +x "$cloudflare_real_ip"

sudo bash "$cloudflare_real_ip" || exit $?

success 'Configured Cloudflare real IP'

#
# Install NGINX Firewall
#
# https://perishablepress.com/8g-firewall/
#

if ! firewall=$(curl -fsSL https://raw.githubusercontent.com/t18d/nG-SetEnvIf/refs/heads/develop/8g-firewall.conf); then
	abort 'Failed to download NGINX firewall'
fi

if ! firewall_site=$(curl -fsSL https://raw.githubusercontent.com/t18d/nG-SetEnvIf/refs/heads/develop/8g.conf); then
	abort 'Failed to download NGINX firewall'
fi

firewall_file=/etc/nginx/http/firewall.conf
firewall_site_file=/etc/nginx/global/firewall.conf

echo "$firewall" | root_write "$firewall_file"
echo "$firewall_site" | root_write "$firewall_site_file"

test_nginx

for site_conf_dir in /etc/nginx/sites-available/*/server/; do
	site_conf_file="$site_conf_dir${firewall_site_file##*/}"
	if [[ ! -L "$site_conf_file" || $(readlink "$site_conf_file") != "$firewall_site_file" ]]; then
		if [[ -e "$site_conf_file" ]] && ! sudo rm "$site_conf_file"; then
			warning "Failed to remove $site_conf_file"
		else
			sudo ln -s "$firewall_site_file" "$site_conf_file"
		fi
	fi
done

test_nginx

success 'Configured NGINX firewall'

#
# Configure fail2ban
#

root_write /etc/fail2ban/fail2ban.local <<'EOF'
[DEFAULT]

allowipv6 = auto

EOF

root_write /etc/fail2ban/paths-overrides.local <<'EOF'
[DEFAULT]

nginx_access_log = /sites/*/logs/access.log
nginx_error_log = /sites/*/logs/error.log

EOF

root_write /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]

bantime = 1d
backend = auto

[sshd]

enabled = true
maxretry = 1

[wp-login]

enabled = true
filter = wp-login
port = http,https
logpath = %(nginx_access_log)s
maxretry = 5
findtime = 10m

[firewall]

enabled = true
filter = firewall
port = http,https
logpath = %(nginx_access_log)s
maxretry = 5
findtime = 10m

EOF

root_write /etc/fail2ban/filter.d/wp-login.conf <<'EOF'
[Definition]

failregex = ^<HOST> .* "POST /+wp-login\.php[^"]*" 200

EOF

root_write /etc/fail2ban/filter.d/firewall.conf <<'EOF'
[Definition]

failregex = ^<HOST> .* "[^"]+" 403

EOF

if ! sudo fail2ban-client reload > /dev/null; then
	abort
fi

success 'Configured jail'
