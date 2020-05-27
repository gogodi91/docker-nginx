#!/bin/bash
envsubst "${CONF_VARIABLES}" < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
exec /usr/local/bin/dockerize -stdout /var/log/nginx/access.log -stderr /var/log/nginx/error.log /usr/sbin/nginx -c /etc/nginx/nginx.conf -g "daemon off;"