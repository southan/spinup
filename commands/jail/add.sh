#!/usr/bin/env bash

jail="${args[--jail]:-}"
if [[ -z $jail ]]; then
	jail=$(sudo fail2ban-client status | grep "Jail list" | sed -E 's/^[^:]+:[ \t]+//' | sed 's/,//g' | awk '{print $1}')
fi

ips=''
# shellcheck disable=SC2154
eval "ips=(${args[ip]})"

sudo fail2ban-client set "$jail" banip "${ips[@]}"
