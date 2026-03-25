#!/usr/bin/env bash

# shellcheck disable=SC2154
jail=${args[jail]}

if [[ -n $jail ]]; then
	if ! jail_status=$(sudo fail2ban-client status "$jail" 2>/dev/null); then
		abort "$jail_status"
	fi

	echo "$jail_status" | grep -oP '(Current|Total).+' | column -t -s '	'

	readarray -t ip_list < <(sudo fail2ban-client get "$jail" banip | tr ' ' '\n')

	if (( ${#ip_list[@]} )); then
		print_numbered_list "${ip_list[@]}"
	fi
else
	for jail in $(sudo fail2ban-client status | grep 'Jail list:' | sed -E 's/^[^:]+:[ \t]+//' | tr ',' ' '); do
		echo "$(status_marker 0) $jail"
		readarray -t info < <(sudo fail2ban-client status "$jail" | grep -oP '(Current|Total).+' | column -t -s '	')
		print_tree_list "${info[@]}"
	done
fi
