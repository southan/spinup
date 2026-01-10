#!/usr/bin/env bash

ips=''
# shellcheck disable=SC2154
eval "ips=(${args[ip]})"
sudo fail2ban-client unban "${ips[@]}"
