#!/usr/bin/env bash

require_site
confirm_site

domain=${args[domain]}
use_dns=${args[--use-dns]}

if [[ -n ${args[--exact]} ]]; then
	domains=("$domain")
else
	domain=${domain#'www.'}
	domains=("$domain" "www.$domain")
fi

site_conf_dir="/etc/nginx/sites-available/$SITE"
site_conf_file="$site_conf_dir/$SITE"
domain_conf_file="$site_conf_dir/after/$domain"

[[ -f $site_conf_file ]] || abort "Site config not found ($site_conf_file)"

if [[ -f $domain_conf_file && -z ${args[--force]} ]]; then
	abort "$domain is already parked on $SITE"
fi

if [[ -z $use_dns ]]; then
	root_write "$domain_conf_file" <<EOF
server {
	listen 80;
	listen [::]:80;
	server_name ${domains[*]};
	root /sites/.certbot/;
}
EOF
	reload_nginx
	certbot_args=(--webroot --webroot-path /sites/.certbot/)
else
	certbot_args=(--manual --preferred-challenges dns)
fi

for _domain in "${domains[@]}"; do
	certbot_args+=(-d "$_domain")
done

if ! sudo certbot certonly "${certbot_args[@]}"; then
	if [[ -z $use_dns ]]; then
		rm "$domain_conf_file"
	fi
	exit 1
fi

ssl_conf="/etc/letsencrypt/renewal/$domain.conf"
ssl_cert="/etc/letsencrypt/live/$domain/fullchain.pem"
ssl_key="/etc/letsencrypt/live/$domain/privkey.pem"

if [[ -f "$ssl_conf" ]] && ! grep -q webroot_path "$ssl_conf"; then
	# Change SSL renewal from DNS challenge to HTTP
	{
		sed -E \
			-e 's/^pref_challs .+/pref_challs = http-01/' \
			-e 's/^authenticator .+/authenticator = webroot/' \
			"$ssl_conf"
		echo 'webroot_path = /sites/.certbot'
		echo '[[webroot_map]]'
		for _domain in "${domains[@]}"; do
			echo "$_domain = /sites/.certbot"
		done
	} | root_write "$ssl_conf"
fi

{
	cat <<EOF
server {
	listen 80;
	listen [::]:80;
	server_name ${domains[@]};

	return 301 https://$domain\$request_uri;
}
EOF
	echo
	sudo awk '/^(server[[:space:]]*\{|}|\s)/' "$site_conf_file" |\
	sed -E "s%server_name .+%server_name ${domains[*]};%" |\
	sed -E "s%ssl_certificate .+%ssl_certificate $ssl_cert;%" |\
	sed -E "s%ssl_certificate_key .+%ssl_certificate_key $ssl_key;%"
} | root_write "$domain_conf_file"

reload_nginx

success "Parked $domain on $SITE"
