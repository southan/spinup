#!/usr/bin/env bash

SPINUP_ACCEPT_SITE() {
	user_has_redis "${SPINUP_USERS[$1]:-$1}"
}

require_sites
confirm_sites

cleanup=()
service_names=()

for site in "${SPINUP_SITES[@]}"; do
	set_site "$site" "${SPINUP_USERS[$site]:-$site}"

	if [[ -z ${SPINUP_USERS[$site]} ]]; then
		:
	elif ! find_site_wp; then
		notice "$site"
		echo '└ No WordPress found'
	elif ! wp_result=$(run_site_wp --skip-wordpress eval-file - 2>&1 <<-PHP
		<?php
		\$config = new WPConfigTransformer( WP_CLI\Utils\locate_wp_config() );
		\$config->remove( 'constant', 'WP_REDIS_SCHEME' );
		\$config->remove( 'constant', 'WP_REDIS_PATH' );
		\$config->remove( 'constant', 'WP_REDIS_PREFIX' );
		PHP
		)
		then
		error "$site"
		echo "└ Failed to configure WordPress: $wp_result"
		continue
	fi

	cleanup+=("$REDIS_SERVICE_FILE")
	cleanup+=("$REDIS_CONFIG_FILE")
	cleanup+=("$SITE_HOME/redis")

	service_names+=("${REDIS_SERVICE_FILE##*/}")
done

if (( ${#cleanup[@]} == 0 )); then
	abort
fi

sudo systemctl --now --quiet disable "${service_names[@]}"
sudo rm -rf "${cleanup[@]}"
sudo systemctl daemon-reload

success 'Redis disabled'
