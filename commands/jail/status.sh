#!/usr/bin/env bash

# shellcheck disable=SC2154
jail=${args[jail]}

if [[ -n $jail ]]; then
	jail_status=$(sudo fail2ban-client status "$jail")
	ip_list=$(echo "$jail_status" | grep 'Banned IP list:' | sed 's/.*Banned IP list:[[:space:]]*//' | tr ' ' '\n')

	echo "$jail_status" | grep -oP '(Current|Total).+' | column -t -s '	'

	if [[ -n $ip_list ]]; then
		count=$(echo "$ip_list" | wc -l)

		echo "$ip_list" | nl -w${#count} -s ') ' | column
	fi
else
	for jail in $(sudo fail2ban-client status | grep 'Jail list:' | sed -E 's/^[^:]+:[ \t]+//' | tr ',' ' '); do
		echo "$(status_marker 0) $jail"
		readarray -t info < <(sudo fail2ban-client status "$jail" | grep -oP '(Current|Total).+' | column -t -s '	')
		print_list "${info[@]}"
	done
fi
