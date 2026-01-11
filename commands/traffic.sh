#!/usr/bin/env bash

if ! command -v goaccess > /dev/null; then
	echo 'Installing traffic monitor (GoAccess)...'
	sudo apt install goaccess -y || exit $?
fi

goaccess /sites/*/logs/access.log --log-format=COMBINED
