#!/usr/bin/env bash

# shellcheck disable=SC2154
require_sites_split_args "${command_line_args[@]:1}"

if [ ! -t 0 ]; then
	stdin=$(cat)
fi

for site in "${SPINUP_SITES[@]}"; do
	set_site "$site"

	if ! find_site_wp; then
		echo "○ $site"
		echo '└ No WordPress found.'
		continue
	fi

	if [ ! -t 0 ]; then
		wp_result=$(printf '%s' "$stdin" | run_site_wp "${SPINUP_ARGS[@]}" 2>&1)
	else
		wp_result=$(run_site_wp "${SPINUP_ARGS[@]}" 2>&1)
	fi

	wp_status=$?

	echo "$(status_marker "$wp_status") $site"
	if [[ -n $wp_result ]]; then
		echo "$wp_result"
	fi
done
