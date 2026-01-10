#!/usr/bin/env bash

init_sites

systemctl list-units 'redis-*' --type=service --all --plain --no-legend --no-pager |
grep -v '^redis-server.service' |
while read -r name loaded service status _; do
	name=${name%.service}
	user=${name#redis-}
	site=${SPINUP_SITES_BY_USER[$user]}

	set_user "$user"

	if [[ $loaded != loaded ]]; then
		add_error "Redis is $loaded"
	elif [[ $status != running ]]; then
		add_error "Redis is $status"
	elif [[ $service != active ]]; then
		add_error "Redis is $service"
	fi

	if [[ -z $site ]]; then
		add_notice "No site found for user"
	fi

	if [[ -n ${args[--ping]} ]]; then
		ping=$(sudo -u "$user" redis-cli -s "$REDIS_SOCKET" PING 2>&1)
		if [[ $ping != PONG ]]; then
			add_error "$ping"
		fi
	fi

	label="$user"
	if [[ -n "$site" ]]; then
		label+=" ($site)"
	fi

	print_messages "$label"
done
