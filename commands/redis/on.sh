#!/usr/bin/env bash

SPINUP_ACCEPT_SITE() {
	! user_has_redis "${SPINUP_USERS[$1]:-$1}"
}

require_sites
confirm_sites

memory=${args[--memory]:-256MB}
service_names=()

for site in "${SPINUP_SITES[@]}"; do
	set_site "$site"

	redis_run_dir=${REDIS_SOCKET%/*}
	redis_config_dir=${REDIS_CONFIG_FILE%/*}

	[[ -d $redis_config_dir ]] || sudo mkdir -p "$redis_config_dir"

	root_write "$REDIS_CONFIG_FILE" <<-EOF
	protected-mode yes

	port 0
	unixsocket $REDIS_SOCKET
	unixsocketperm 600

	pidfile ${REDIS_SOCKET/.sock/.pid}
	logfile $SITE_HOME/logs/redis.log
	loglevel notice

	maxmemory $memory
	maxmemory-policy allkeys-lfu

	dir $SITE_HOME/redis
	dbfilename dump.rdb
	databases 1

	save ""
	timeout 0
	daemonize no
	appendonly no
	always-show-logo no
	set-proc-title yes
	proc-title-template "{title} {listen-addr} {server-mode}"
	locale-collate ""
	stop-writes-on-bgsave-error yes
	rdbcompression yes
	rdbchecksum yes
	rdb-del-sync-files no
	replica-serve-stale-data yes
	replica-read-only yes
	repl-diskless-sync yes
	repl-diskless-sync-delay 5
	repl-diskless-sync-max-replicas 0
	repl-diskless-load disabled
	repl-disable-tcp-nodelay no
	replica-priority 100
	acllog-max-len 128
	lazyfree-lazy-eviction no
	lazyfree-lazy-expire no
	lazyfree-lazy-server-del no
	replica-lazy-flush no
	lazyfree-lazy-user-del no
	lazyfree-lazy-user-flush no
	oom-score-adj no
	oom-score-adj-values 0 200 800
	disable-thp yes

	slowlog-log-slower-than 10000
	slowlog-max-len 128
	latency-monitor-threshold 0
	notify-keyspace-events ""
	hash-max-listpack-entries 512
	hash-max-listpack-value 64
	list-max-listpack-size -2
	list-compress-depth 0
	set-max-intset-entries 512
	set-max-listpack-entries 128
	set-max-listpack-value 64
	zset-max-listpack-entries 128
	zset-max-listpack-value 64
	hll-sparse-max-bytes 3000
	stream-node-max-bytes 4096
	stream-node-max-entries 100
	activerehashing yes
	client-output-buffer-limit normal 0 0 0
	client-output-buffer-limit replica 256mb 64mb 60
	client-output-buffer-limit pubsub 32mb 8mb 60
	hz 10
	dynamic-hz yes
	aof-rewrite-incremental-fsync yes
	rdb-save-incremental-fsync yes
	jemalloc-bg-thread yes
	EOF

	root_write "$REDIS_SERVICE_FILE" <<-EOF
	[Unit]
	Description=Redis for $SITE_USER
	After=network.target
	Documentation=http://redis.io/documentation, man:redis-server(1)

	[Service]
	Type=notify
	ExecStart=/usr/bin/redis-server $REDIS_CONFIG_FILE --supervised systemd
	TimeoutStartSec=30
	TimeoutStopSec=30
	User=$SITE_USER
	Group=$SITE_USER
	RuntimeDirectory=${redis_run_dir##*/}

	UMask=007
	LimitNOFILE=65535
	PrivateTmp=yes
	PrivateDevices=yes
	ProtectHome=yes
	ProtectSystem=full
	ReadOnlyDirectories=/
	ReadWriteDirectories=-$redis_run_dir
	ReadWriteDirectories=-$SITE_HOME/redis
	ReadWriteDirectories=-$SITE_HOME/logs

	NoNewPrivileges=true
	CapabilityBoundingSet=CAP_SYS_RESOURCE
	RestrictAddressFamilies=AF_UNIX
	MemoryDenyWriteExecute=true
	ProtectKernelModules=true
	ProtectKernelTunables=true
	ProtectControlGroups=true
	RestrictRealtime=true
	RestrictNamespaces=true

	[Install]
	WantedBy=multi-user.target
	EOF

	service_names+=("${REDIS_SERVICE_FILE##*/}")
done

sudo systemctl daemon-reload
sudo systemctl --quiet enable "${service_names[@]}"
sudo systemctl restart "${service_names[@]}"

for site in "${SPINUP_SITES[@]}"; do
	set_site "$site"

	if ! find_site_wp; then
		notice "$site"
		echo '└ No WordPress found'

	elif wp_result=$(run_site_wp eval-file - 2>&1 <<-PHP
		<?php
		\$options = [
			'anchor' => '<?php',
			'placement' => 'after',
		];
		\$config = new WPConfigTransformer( WP_CLI\Utils\locate_wp_config() );
		\$config->remove( 'constant', 'WP_REDIS_DISABLED' );
		\$config->update( 'constant', 'WP_REDIS_SCHEME', 'unix', \$options );
		\$config->update( 'constant', 'WP_REDIS_PATH', '$REDIS_SOCKET', \$options );
		\$config->update( 'constant', 'WP_REDIS_PREFIX', '', \$options );
		PHP
		)
		then
		success "$site"
	else
		error "$site"
		echo "└ Failed to configure WordPress: $wp_result"
	fi
done
