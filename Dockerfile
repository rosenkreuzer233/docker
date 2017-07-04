FROM debian:stretch-slim

MAINTAINER NGINX Docker Maintainers "docker-maint@nginx.com"

ENV NGINX_VERSION 1.12.0-1~stretch
ENV NJS_VERSION   1.12.0.0.1.10-1~stretch

RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y gnupg1 \
	&& \
	NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
	apt-get remove --purge -y gnupg1 && apt-get -y --purge autoremove && rm -rf /var/lib/apt/lists/* \
	&& echo "deb http://nginx.org/packages/debian/ stretch nginx" >> /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
						nginx=${NGINX_VERSION} \
						nginx-module-xslt=${NGINX_VERSION} \
						nginx-module-geoip=${NGINX_VERSION} \
						nginx-module-image-filter=${NGINX_VERSION} \
						nginx-module-njs=${NJS_VERSION} \
						gettext-base \
                        			php-fpm \
						php-gd \
						php-zip \
						php-xml \
						unzip \
						axel \
						supervisor

# Hacks Nginx and php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php_conf} && \
	sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${php_conf} && \
	sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${php_conf} && \
	sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php_conf} && \
	sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" ${fpm_conf} && \
	sed -i -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" ${fpm_pool} && \
	sed -i -e "s/listen.owner = www-data/listen.owner = nginx/g" ${fpm_pool} && \
	sed -i -e "s/listen.group = www-data/listen.group = nginx/g" ${fpm_pool} && \
	sed -i -e "s/user = www-data/user = nginx/g" ${fpm_pool} && \
	sed -i -e "s/group = www-data/group = nginx/g" ${fpm_pool} && \
	echo "daemon off;" >> ${nginx_conf}

# Cleaning
RUN rm -rf /etc/nginx/conf.d/* && \
    rm -rf /usr/share/nginx/html/* && \
	rm -rf /var/lib/apt/lists/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log


# Configurations files
ADD conf/default.conf /etc/nginx/conf.d/default.conf
ADD conf/supervisord.conf /etc/supervisord.conf

# Nginx logs to Docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
	ln -sf /dev/stderr /var/log/nginx/error.log

# Bludit installation
RUN cd /tmp/; \
	axel ${bludit_zip} -o /tmp/bludit.zip; \
	unzip /tmp/bludit.zip; \
	rm -rf /usr/share/nginx/html; \
	cp -r /tmp/bludit /usr/share/nginx/html; \
	chown -R nginx:nginx /usr/share/nginx/html/*; \
	chmod 755 /usr/share/nginx/html/bl-content; \
	rm /tmp/bludit.zip; \
	rm -rf /tmp/bludit

EXPOSE 80

CMD ["/usr/bin/supervisord", "-n", "-c",  "/etc/supervisord.conf"]