#!/usr/bin/env bash

# shellcheck disable=SC2154
require_sites_split_args "${command_line_args[@]:1}"

script=''
if [[ ${#SPINUP_ARGS[@]} == 1 && -f ${SPINUP_ARGS[0]} ]]; then
	script=$(cat "${SPINUP_ARGS[0]}")
fi

for site in "${SPINUP_SITES[@]}"; do
	set_site "$site"

	if [[ -n $script ]]; then
		# shellcheck disable=SC2153
		result=$(cd "$SITE_HOME" && sudo -u "$SITE_USER" bash <<-EOF
		SITE="$SITE"
		SITE_USER="$SITE_USER"
		$script
		EOF
		)
	else
		result=$(cd "$SITE_HOME" && sudo -u "$SITE_USER" "${SPINUP_ARGS[@]}")
	fi

	echo "$(status_marker "$?") $site"
	if [[ -n $result ]]; then
		echo "$result"
	fi
done
