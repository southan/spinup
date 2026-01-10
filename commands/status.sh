#!/usr/bin/env bash

if [[ -n ${args[site]} ]]; then
	require_sites
else
	init_sites
fi

for site in "${SPINUP_SITES[@]}"; do
	set_site "$site"

	wp_redis_status=''
	wp_redis_path=''
	wp_redis_scheme=''

	if find_site_wp; then
		if wp_dump=$(
			run_site_wp eval-file - 2>&1 <<-'PHP'
			<?php

			global $wp_object_cache;

			if ( defined( 'WP_REDIS_DISABLED' ) && WP_REDIS_DISABLED ) {
				$redis_status = 'disabled';
			} elseif ( ! method_exists( $wp_object_cache, 'redis_status' ) ) {
				$redis_status = 'missing';
			} elseif ( ! $wp_object_cache->redis_status() ) {
				$redis_status = 'error';
			} else {
				$redis_status = 'connected';
			}

			echo implode( "\n", [
				$redis_status,
				defined( 'WP_REDIS_SCHEME' ) ? WP_REDIS_SCHEME : '',
				defined( 'WP_REDIS_PATH' ) ? WP_REDIS_PATH : '',
				'--END--',
			]);
			PHP
		); then
			readarray -t wp_info < <(echo "$wp_dump" | tail -n 4)
			wp_redis_status=${wp_info[0]}
			wp_redis_scheme=${wp_info[1]}
			wp_redis_path=${wp_info[2]}
		else
			add_error "$wp_dump"
		fi
	fi

	if [[ -n $wp_redis_path || -f $REDIS_CONFIG_FILE || -f $REDIS_SERVICE_FILE || -S $REDIS_SOCKET ]]; then
		defined_redis_socket=${wp_redis_path:-$REDIS_SOCKET}
		if [[ -S $defined_redis_socket ]]; then
			redis_ping=$(sudo -u "$SITE_USER" redis-cli -s "$defined_redis_socket" PING 2>&1)

			if [[ $redis_ping != PONG ]]; then
				add_error "$redis_ping"
			fi
		elif [[ $wp_redis_status != disabled ]]; then
			add_error "Redis socket missing ($defined_redis_socket)"
		fi
	fi

	if [[ $wp_redis_status == disabled ]]; then
		add_warning 'Redis is disabled with WP_REDIS_DISABLED'
	elif [[ $wp_redis_status == missing ]]; then
		add_warning 'WordPress is missing Redis object cache dropin'
	elif [[ $wp_redis_status == error ]]; then
		add_error 'WordPress failed to connect to Redis'
	elif [[ $wp_redis_status == connected ]] && [[ -z $wp_redis_path || $wp_redis_scheme != 'unix' ]]; then
		add_notice 'Using shared Redis.'
	fi

	if [[ -n $wp_redis_path && $wp_redis_scheme != unix ]]; then
		add_warning "WP_REDIS_SCHEME is ${wp_redis_scheme:-not set} (should be 'unix')"
	elif [[ $wp_redis_scheme == unix && -z $wp_redis_path ]]; then
		add_error "WP_REDIS_SCHEME is 'unix' but WP_REDIS_PATH is not set"
	elif [[ -n $wp_redis_path && $wp_redis_path != "$REDIS_SOCKET" ]]; then
		add_warning "WP_REDIS_PATH is '$wp_redis_path' (expected '$REDIS_SOCKET')"
	fi

	print_messages "$site"
done
