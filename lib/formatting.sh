#!/usr/bin/env bash

success() {
	echo "$(green ✓) $1"
}

error() {
	echo "$(red ✗) $1" >&2
}

warning() {
	echo "$(yellow ⚠) $1" >&2
}

notice() {
	echo "$(cyan ⓘ) $1" >&2
}

status_marker() {
	case $1 in
		0) green ●;;
		1) red ●;;
		2) yellow ●;;
		3) cyan ●;;
		*) echo ○;;
	esac
}

SPINUP_ERRORS=()
SPINUP_WARNINGS=()
SPINUP_NOTICES=()

add_error() {
	SPINUP_ERRORS+=("$1")
}

add_warning() {
	SPINUP_WARNINGS+=("$1")
}

add_notice() {
	SPINUP_NOTICES+=("$1")
}

print_list() {
	local count=$#
	local prefix

	for (( i=1; i<=count; i++ )); do
		(( i == count )) && prefix='└' || prefix='├'
		echo "$prefix ${!i}"
	done
}

print_messages() {
	local label=$1

	if [[ -n $label ]]; then
		local status=0

		if (( ${#SPINUP_ERRORS[@]} )); then
			status=1
		elif (( ${#SPINUP_WARNINGS[@]} )); then
			status=2
		elif (( ${#SPINUP_NOTICES[@]} )); then
			status=3
		fi

		echo "$(status_marker $status) $label"
	fi

	local messages
	messages=(
		"${SPINUP_ERRORS[@]/#/"$(red ✗) "}"
		"${SPINUP_WARNINGS[@]/#/"$(yellow ⚠) "}"
		"${SPINUP_NOTICES[@]/#/"$(cyan ⓘ) "}"
	)

	SPINUP_ERRORS=()
	SPINUP_WARNINGS=()
	SPINUP_NOTICES=()

	if (( ${#messages[@]} == 0 )); then
		return 0
	fi

	if [[ -z $label ]]; then
		printf '%s\n' "${messages[@]}"
	else
		print_list "${messages[@]}"
	fi
}
