#!/usr/bin/env bash

for site in /etc/nginx/sites-available/*/; do
	readarray -t parked < <(find "${site}after/" -type f -not -name '*.conf' 2>/dev/null)
	if (( ${#parked[@]} )); then
		parked=("${parked[@]##*/}")
		basename "$site"
		print_list "${parked[@]}"
	fi
done
