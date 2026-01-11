#!/usr/bin/env bash

read_ini /etc/fail2ban/jail.local

ignore_ips=${ini[DEFAULT.ignoreip]}

if [[ -n ${args[ip]} ]]; then
	ips=''
	eval "ips=(${args[ip]})"
	ignore_ips=" ${ignore_ips} "
	for ip in "${ips[@]}"; do
		if [[ " $ignore_ips " == *" $ip "* ]]; then
			if [[ -n ${args[--clear]} ]]; then
				ignore_ips=${ignore_ips/" $ip "/' '}
				success "$ip unignored"
			else
				warning "$ip already ignored"
			fi
		elif [[ -n ${args[--clear]} ]]; then
			warning "$ip is not ignored"
		else
			ignore_ips+="$ip "
			success "$ip ignored"
		fi
	done

	ini[DEFAULT.ignoreip]=$(echo "$ignore_ips" | sed 's/^ *//;s/ *$//')
	save_ini
	sudo fail2ban-client reload > /dev/null

elif [[ -n ${args[--clear]} && -n $ignore_ips ]]; then
	if ! confirm 'Clear ignored IPs?'; then
		abort
	fi

	ini[DEFAULT.ignoreip]=''
	save_ini
	sudo fail2ban-client reload > /dev/null

	success 'Ignore list cleared'

elif [[ -z $ignore_ips ]]; then
	echo 'No ignored IPs'

else
	# shellcheck disable=SC2086
	print_numbered_list $ignore_ips
fi
