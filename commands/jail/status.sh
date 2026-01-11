#!/usr/bin/env bash

# shellcheck disable=SC2154
jail=${args[jail]}

if [[ -n $jail ]]; then
	jail_status=$(sudo fail2ban-client status "$jail")

	echo "$jail_status" | grep -oP '(Current|Total).+' | column -t -s '	'

	ip_list=$(echo "$jail_status" | grep 'Banned IP list:' | sed 's/.*Banned IP list:[[:space:]]*//')

	if [[ -n $ip_list ]]; then
		# shellcheck disable=SC2086
		print_numbered_list $ip_list
	fi
else
	for jail in $(sudo fail2ban-client status | grep 'Jail list:' | sed -E 's/^[^:]+:[ \t]+//' | tr ',' ' '); do
		echo "$(status_marker 0) $jail"
		readarray -t info < <(sudo fail2ban-client status "$jail" | grep -oP '(Current|Total).+' | column -t -s '	')
		print_tree_list "${info[@]}"
	done
fi
