#!/usr/bin/env bash

# shellcheck disable=SC2154
jail=${args[jail]}

if [[ -n $jail ]]; then
	sudo fail2ban-client status "$jail"
else
	for jail in $(sudo fail2ban-client status | grep 'Jail list:' | sed -E 's/^[^:]+:[ \t]+//' | tr ',' ' '); do
		echo "$(status_marker 0) $jail"
		readarray -t info < <(sudo fail2ban-client status "$jail" | grep -oP '(Current|Total).+' | column -t -s '	')
		print_list "${info[@]}"
	done
fi
