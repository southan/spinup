#!/usr/bin/env bash

# shellcheck disable=SC2154
wp_args=("${command_line_args[@]:1}")

split_at=-1
for split_at in "${!wp_args[@]}"; do
	if [[ ${wp_args[$split_at]} == -- ]]; then
		break
	fi
	split_at=-1
done

if (( split_at > -1 )); then
	sites=("${wp_args[@]:0:split_at}")
	# shellcheck disable=SC2034
	wp_args=("${wp_args[@]:split_at+1}")

	require_sites "${sites[@]}"
else
	init_sites
fi

for site in "${SPINUP_SITES[@]}"; do
	set_site "$site"

	if ! find_site_wp; then
		echo "○ $site"
		echo '└ No WordPress found.'
		continue
	fi

	wp_result=$(run_site_wp "${wp_args[@]}" 2>&1)
	wp_status=$?

	echo "$(status_marker "$wp_status") $site"
	if [[ -n $wp_result ]]; then
		echo "$wp_result"
	fi
done
