#!/usr/bin/env bash

list_sites | while read -r site _; do
	echo "$site"
done
