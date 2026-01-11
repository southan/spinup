#!/usr/bin/env bash

set_site() {
	SITE=$1
	SITE_HOME="/sites/$SITE"
	set_user "${2:-${SPINUP_USERS[$SITE]}}"
}

set_user() {
	SITE_USER=$1
	REDIS_SOCKET="/run/redis-$SITE_USER/redis-$SITE_USER.sock"
	REDIS_CONFIG_FILE="/etc/redis.d/redis-$SITE_USER.conf"
	REDIS_SERVICE_FILE="/etc/systemd/system/redis-$SITE_USER.service"
}

list_sites() {
	find /sites/ -mindepth 1 -maxdepth 1 -type d -not -name '.*' -printf '%f\t%u\n' |
	while read -r site user; do
		printf '%s\t%s\t%s\n' "${site#www.}" "$site" "$user"
	done |
	sort |
	cut -f2-
}

init_sites() {
	SPINUP_SITES=()
	declare -gA SPINUP_USERS=()
	declare -gA SPINUP_SITES_BY_USER=()

	declare -F SPINUP_SITES_FILTER > /dev/null
	local skip_filter=$?

	local site user
	while read -r site user; do
		SPINUP_USERS[$site]=$user
		SPINUP_SITES_BY_USER[$user]=$site
		if (( skip_filter )) || SPINUP_SITES_FILTER "$site"; then
			SPINUP_SITES+=("$site")
		fi
	done < <(list_sites)
}

match_sites() {
	local matched_sites=()

	local has_accept
	declare -F SPINUP_ACCEPT_SITE > /dev/null && has_accept=1 || has_accept=0

	local arg
	local site
	local site_index
	for arg in "$@"; do
		if [[ $arg == '!'* ]]; then
			arg=${arg#!}
			(( ${#matched_sites[@]} )) || matched_sites=("${SPINUP_SITES[@]}")
			for site_index in "${!matched_sites[@]}"; do
				site=${matched_sites[$site_index]}
				# shellcheck disable=SC2053
				if [[ $site == $arg || ${SPINUP_USERS[$site]} == $arg ]]; then
					unset "matched_sites[$site_index]"
				fi
			done
		elif [[ $arg == *'*'* ]]; then
			for site in "${SPINUP_SITES[@]}"; do
				# shellcheck disable=SC2053
				if [[ $site == $arg || ${SPINUP_USERS[$site]} == $arg ]]; then
					matched_sites+=("$site")
				fi
			done
		elif [[ -n ${SPINUP_USERS[$arg]} ]]; then
			matched_sites+=("$arg")
		elif [[ -n ${SPINUP_SITES_BY_USER[$arg]} ]]; then
			matched_sites+=("${SPINUP_SITES_BY_USER[$arg]}")
		elif (( has_accept )) && SPINUP_ACCEPT_SITE "$arg"; then
			matched_sites+=("$arg")
		elif (( has_accept )); then
			abort "Site '$arg' is not available"
		else
			abort "Site '$arg' not found"
		fi
	done

	readarray -t SPINUP_SITES < <(printf '%s\n' "${matched_sites[@]}" | uniq)
}

select_sites() {
	local limit=$1
	local count=${#SPINUP_SITES[@]}

	printf '%s\n' "${SPINUP_SITES[@]}" | nl -w${#count} -s ') ' | column

	local choice
	local choices=()

	if [[ $limit == 1 ]]; then
		read -r -p 'Choose site: ' choice

		if [[ -z $choice ]]; then
			abort
		fi

		choices=("$choice")
	else
		read -r -p 'Choose site(s) (or continue): ' -a choices

		if (( ${#choices} == 0 )); then
			return 0
		fi
	fi

	local selected_sites=()

	local index
	for choice in "${choices[@]}"; do
		if [[ $choice =~ ^[0-9]+$ ]]; then
			index=$((choice - 1))

			if [[ -n ${SPINUP_SITES[$index]} ]]; then
				selected_sites+=("${SPINUP_SITES[$index]}")
			else
				abort "Invalid option #$choice"
			fi
		elif [[ " ${SPINUP_SITES[*]} " == *" $choice "* ]]; then
			selected_sites+=("$choice")
		else
			abort "Invalid choice '$choice'"
		fi
	done

	readarray -t SPINUP_SITES < <(printf '%s\n' "${selected_sites[@]}" | uniq)
}

require_sites() {
	init_sites

	local sites=("$@")
	if (( ${#sites[@]} == 0 )) && [[ -n ${args[site]} ]]; then
		eval "sites=(${args[site]})"
	fi

	if (( ${#sites[@]} )); then
		match_sites "${sites[@]}"
	elif [[ -z ${args[--all]} ]]; then
		select_sites
	fi

	if (( ${#SPINUP_SITES[@]} == 0 )); then
		abort 'No sites found.'
	fi
}

require_site() {
	init_sites

	local site="${1:-${args[site]}}"

	if [[ -n $site ]]; then
		match_sites "$site"
	else
		select_sites 1
	fi

	case ${#SPINUP_SITES[@]} in
		1) ;;
		0) abort 'No site found.' ;;
		*) abort "More than one site found: ${SPINUP_SITES[*]}" ;;
	esac

	set_site "${SPINUP_SITES[0]}"
}

confirm_sites() {
	if (( ${#SPINUP_SITES[@]} == 1 )); then
		if ! confirm "Continue for ${SPINUP_SITES[*]}?"; then
			abort
		fi
	else
		printf '● %s\n' "${SPINUP_SITES[@]}" | column
		if ! confirm 'Continue?'; then
			abort
		fi
	fi
}

confirm_site() {
	if ! confirm "Continue for $SITE?"; then
		abort
	fi
}

find_site_wp() {
	[[ -v SPINUP_SITES_WP ]] || declare -gA SPINUP_SITES_WP

	if [[ -v "SPINUP_SITES_WP[$SITE]" ]]; then
		SITE_WP=${SPINUP_SITES_WP[$SITE]}
	else
		SITE_WP="$SITE_HOME/files"

		if [[ ! -f "$SITE_WP/wp-load.php" ]]; then
			local wp_load_file
			wp_load_file=$(find "$SITE_WP" -maxdepth 3 -type f -name wp-load.php -print -quit 2>/dev/null)

			if [[ -n $wp_load_file ]]; then
				SITE_WP="${wp_load_file%/*}"
			else
				SITE_WP=''
			fi
		fi

		SPINUP_SITES_WP[$SITE]=$SITE_WP
	fi

	[[ -n $SITE_WP ]]
}

run_site_wp() {
	if [[ -z $SITE_WP ]]; then
		return 1
	fi

	sudo -u "$SITE_USER" wp --path="$SITE_WP" "$@"
}

user_has_redis() {
	if [[ ! -v REDIS_SERVICES ]]; then
		readarray -t REDIS_SERVICES < <(systemctl list-units 'redis-*.service' --all --plain --no-legend --no-pager | cut -f1 -d' ')
	fi

	[[ " ${REDIS_SERVICES[*]} " == *" redis-$1.service "* ]]
}
