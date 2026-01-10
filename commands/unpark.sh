#!/usr/bin/env bash

require_site
confirm_site

domain="${args[domain]}"
domain_root=$domain

if [[ -z "${args[--exact]}" ]]; then
	domain_root="${domain#'www.'}"
fi

domain_conf="/etc/nginx/sites-available/$SITE/after/$domain_root"

[[ -f "$domain_conf" ]] || abort "$domain is not parked on $SITE"

sudo rm -rf \
	"$domain_conf" \
	"/etc/letsencrypt/renewal/$domain_root.conf" \
	"/etc/letsencrypt/archive/$domain_root/" \
	"/etc/letsencrypt/live/$domain_root/"

reload_nginx

success "Unparked $domain"
