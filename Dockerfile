FROM debian:stretch-slim

ENV NGINX_VERSION release-1.17.7
ENV OPENLDAP_ROOT_PASSWORD ""
ENV LDAP_HOST ""
ENV OPENLDAP_ROOT_CN ""
ENV OPENLDAP_ORG ""
ENV PACKAGES_LIST "ca-certificates libpcre3-dev zlib1g-dev ldap-utils libldap2-dev libssl-dev gettext-base"
ENV BUILD_PACKAGES_LIST "git gcc make wget"

LABEL maintainer="Ravindra Bhadti"

#COPY resources/bin/nginx_run.sh /usr/local/bin/nginx_run.sh

#RUN useradd -u 1001 -g www-data nginx && \
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    echo 'deb http://ftp.debian.org/debian/ stretch-backports main' > /etc/apt/sources.list.d/backports.list && \
    apt-get update && \
    apt-get install -t stretch-backports -y ${PACKAGES_LIST} ${BUILD_PACKAGES_LIST} && \
    mkdir /var/log/nginx && \
    mkdir -p /var/cache/nginx &&\
    mkdir /etc/nginx && \
    # chmod a+x /usr/local/bin/nginx_run.sh && \
    cd /root && \
    git clone https://github.com/kvspb/nginx-auth-ldap.git && \
    git clone https://github.com/nginx/nginx.git && \
    cd /root/nginx && \
    git checkout tags/${NGINX_VERSION} && \
    ./auto/configure \
        --add-module=/root/nginx-auth-ldap \
        --with-http_ssl_module \
        --with-debug \
        --conf-path=/etc/nginx/nginx.conf \
        --sbin-path=/usr/sbin/nginx \
        --pid-path=/var/cache/nginx/nginx.pid \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --with-stream \
        --with-stream_ssl_module \
        --with-debug \
        --with-file-aio \
        --with-threads \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_v2_module \
        --with-http_auth_request_module \
        --with-http_sub_module && \
    make install && \
    cd .. && \
    rm -rf nginx-auth-ldap && \
    rm -rf nginx && \
    wget -O /tmp/dockerize.tar.gz https://github.com/jwilder/dockerize/releases/download/v0.2.0/dockerize-linux-amd64-v0.2.0.tar.gz && \
    tar -C /usr/local/bin -xzvf /tmp/dockerize.tar.gz && \
    rm -rf /tmp/dockerize.tar.gz && \
    rm -rf nginx-auth-ldap/ nginx/ && \
    apt-get -y purge binutils openssh-* ${BUILD_PACKAGES_LIST} && \
    apt-get -y remove libbsd0 && \
    apt -y autoremove && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log
	

#COPY resources/config /etc/nginx

# RUN chown -R 1001 /etc/nginx && chown -R 1001 /usr/sbin/nginx

# implement changes required to run NGINX as an unprivileged user
#RUN usermod -u 1001 nginx && \
RUN useradd -u 1001 nginx && \
	chown -R 1001 /var/cache/nginx && \
    chown -R 1001 /etc/nginx && \
	chmod -R g+w /var/cache/nginx && \
    chmod 755 /usr/sbin/nginx && \
	sed -i -e '/user/!b' -e '/nginx/!b' -e '/nginx/d' /etc/nginx/nginx.conf && \
    sed -i -e '/listen/!b' -e '/80;/!b' -e 's/80;/8080;/' /etc/nginx/nginx.conf && \
	sed -i "s!/var/run/nginx.pid!/var/cache/nginx/nginx.pid!g" /etc/nginx/nginx.conf && \
    sed -i "/^http {/a \    proxy_temp_path /var/cache/nginx/proxy_temp;\n    client_body_temp_path /var/cache/nginx/client_temp;\n    fastcgi_temp_path /var/cache/nginx/fastcgi_temp;\n    uwsgi_temp_path /var/cache/nginx/uwsgi_temp;\n    scgi_temp_path /var/cache/nginx/scgi_temp;\n" /etc/nginx/nginx.conf

STOPSIGNAL SIGTERM

USER 1001

# Cannot run on port 80 due to not running as root.
EXPOSE 8080

ENTRYPOINT [ "/usr/sbin/nginx" ]

CMD ["-c", "/etc/nginx/nginx.conf", "-g", "daemon off;"]