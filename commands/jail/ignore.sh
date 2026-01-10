#!/usr/bin/env bash

add_ignore=${args[ip]:-}

read_ini /etc/fail2ban/jail.local

ips=${ini[DEFAULT.ignoreip]}

if [[ -z $add_ignore ]]; then
	if [[ -z $ips ]]; then
		echo 'No ignored IPs.'
	else
		for ip in $ips; do
			echo "$ip"
		done
	fi
	exit
fi

results=''

for ip in $add_ignore; do
	if [[ " $add_ignore " != *" $ip "* ]]; then
		ips+=" $ip"
		results+=$(success "$ip added")
	else
		results+=$(warning "$ip already ignored")
	fi
done

ini[DEFAULT.ignoreip]=$ips

save_ini

printf '%s' "$results"
