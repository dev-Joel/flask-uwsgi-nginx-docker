#!/usr/bin/env sh
set -e

export PYTHONPATH=$PYTHONPATH:/usr/local/lib/python3.7/site-packages:/usr/lib/python3.7/site-packages

USE_NGINX_MAX_UPLOAD=${NGINX_MAX_UPLOAD:-0}
USE_NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-1}
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-1024}

# listen port
USE_LISTEN_PORT=${LISTEN_PORT:-80}

if [ -f /app/nginx.conf ]; then
    cp /app/nginx.conf /etc/nginx/nginx.conf
else
    content='user  nginx;\n'
    content=$content"worker_processes ${USE_NGINX_WORKER_PROCESSES};\n"
    content=$content'error_log  /var/log/nginx/error.log warn;\n'
    content=$content'pid        /var/run/nginx.pid;\n'
    content=$content'events {\n'
    content=$content"    worker_connections ${NGINX_WORKER_CONNECTIONS};\n"
    content=$content'}\n'
    content=$content'http {\n'
    content=$content'    include       /etc/nginx/mime.types;\n'
    content=$content'    default_type  application/octet-stream;\n'
    content=$content'    log_format  main  '"'\$remote_addr - \$remote_user [\$time_local] \"\$request\" '\n"
    content=$content'                      '"'\$status \$body_bytes_sent \"\$http_referer\" '\n"
    content=$content'                      '"'\"\$http_user_agent\" \"\$http_x_forwarded_for\"';\n"
    content=$content'    access_log  /var/log/nginx/access.log  main;\n'
    content=$content'    sendfile        on;\n'
    content=$content'    keepalive_timeout  65;\n'
    content=$content'    include /etc/nginx/conf.d/*.conf;\n'
    content=$content'}\n'
    content=$content'daemon off;\n'
    if [ -n "${NGINX_WORKER_OPEN_FILES}" ] ; then
        content=$content"worker_rlimit_nofile ${NGINX_WORKER_OPEN_FILES};\n"
    fi

    printf "$content" > /etc/nginx/nginx.conf

    content_server='server {\n'
    content_server=$content_server"    listen ${USE_LISTEN_PORT};\n"
    content_server=$content_server'    location / {\n'
    content_server=$content_server'        try_files $uri @app;\n'
    content_server=$content_server'    }\n'
    content_server=$content_server'    location @app {\n'
    content_server=$content_server'        include uwsgi_params;\n'
    content_server=$content_server'        uwsgi_pass unix:///tmp/uwsgi.sock;\n'
    content_server=$content_server'    }\n'
    content_server=$content_server"    location $USE_STATIC_URL {\n"
    content_server=$content_server"        alias $USE_STATIC_PATH;\n"
    content_server=$content_server'    }\n'
    content_server=$content_server'}\n'
    
    printf "$content_server" > /etc/nginx/conf.d/nginx.conf

    # maximum upload file size
    printf "client_max_body_size $USE_NGINX_MAX_UPLOAD;\n" > /etc/nginx/conf.d/upload.conf

fi

exec "$@"
