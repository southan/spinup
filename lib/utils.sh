#!/usr/bin/env bash

abort() {
	[[ -n $1 ]] && echo "$(red ✗) $1" >&2
	exit 1
}

confirm() {
	local answer
	read -r -n 1 -p "$1 [y/N] " answer
	echo ""
	case "$answer" in
		[yY]) return 0 ;;
		*) return 1 ;;
	esac
}

read_ini() {
 	declare -g SPINUP_INI_FILE
 	SPINUP_INI_FILE=$1
	ini_load "$SPINUP_INI_FILE"
}

save_ini() {
 	declare -g SPINUP_INI_FILE
 	[[ -z $SPINUP_INI_FILE ]] && abort 'No INI file loaded.'
	local name
	name="$(basename "$SPINUP_INI_FILE" '.ini')-$RANDOM.ini"
	ini_save "$HOME/$name"
	sudo mv "$HOME/$name" "$SPINUP_INI_FILE"
	sudo chown root:root "$SPINUP_INI_FILE"
}

root_write() {
	if ! sudo tee "$1" >/dev/null; then
		abort "Failed to write to $1"
	fi
}

test_nginx() {
	if ! sudo nginx -t -q; then
		abort
	fi
}

reload_nginx() {
	test_nginx
	local output
	if ! output=$(sudo nginx -s reload 2>&1); then
		abort "$output"
	fi
}
