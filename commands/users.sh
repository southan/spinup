#!/usr/bin/env bash

list_sites | while read -r _ user; do
	echo "$user"
done
