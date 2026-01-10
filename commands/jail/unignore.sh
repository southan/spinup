#!/usr/bin/env bash

declare -A ips

for ip in ${args[ip]:-}; do
	ips["$ip"]=1
done

read_ini /etc/fail2ban/jail.local

ignoreips=()

for ip in ${ini[DEFAULT.ignoreip]}; do
	if [[ -z "${ips[$ip]}" ]]; then
		ignoreips+=("$ip")
	else
		ips[$ip]=2
	fi
done

ini[DEFAULT.ignoreip]="${ignoreips[*]}"

save_ini

for ip in "${!ips[@]}"; do
	if [[ 2 = "${ips[$ip]}" ]]; then
		success "$ip removed."
	else
		warning "$ip not ignored."
	fi
done
