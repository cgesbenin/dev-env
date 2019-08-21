FROM php:7.3.8-fpm

RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
                        supervisor \
                        wget \
                        curl \
                        dos2unix \
                        software-properties-common \
                        zip \
                        unzip \
                        zlib1g-dev \
                        libpng-dev \
                        libicu-dev \
                        g++ \
                        libmagickwand-dev \
                        openssl \
                        procps \
                        net-tools \
                        jq \
                        libedit-dev \
                        libfcgi0ldbl \
                        libfreetype6-dev \
                        libicu-dev \
                        libjpeg62-turbo-dev \
                        libmcrypt-dev \
                        libpng-dev \
                        libpq-dev \
                        libssl-dev \
                        libwebp-dev \
                        libxpm-dev \
                        mcrypt \
                        openssh-client \
                        gnupg2 \
                        dirmngr \
    && pecl install mcrypt-1.0.2 \
    && docker-php-ext-enable mcrypt \
    && pecl install imagick \
    && docker-php-ext-install exif \
    && docker-php-ext-enable exif \
    && docker-php-ext-enable imagick \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-configure gd --with-gd --with-webp-dir --with-jpeg-dir \
        --with-png-dir --with-zlib-dir --with-xpm-dir --with-freetype-dir \
        --enable-gd-native-ttf \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install pdo pdo_pgsql pgsql intl opcache json readline gd \
    && apt-get upgrade -y \
	&& rm -rf /var/lib/apt/listl s/*

RUN NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
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
	echo "deb http://nginx.org/packages/debian/ stretch nginx" >> /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
    					nginx \
						nginx-module-xslt \
						nginx-module-geoip \
						nginx-module-image-filter \
						gettext-base \
	&& rm -rf /var/lib/apt/lists/*

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

RUN wget -nv -O /tmp/wkhtmltox.deb https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.stretch_amd64.deb \
    && apt-get update && apt-get -qy install /tmp/wkhtmltox.deb --no-install-recommends \
    && rm -f /tmp/wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/*


RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/bin --filename=composer \
    && php -r "unlink('composer-setup.php');"



RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && apt-get install --no-install-recommends --no-install-suggests -y nodejs \
    && rm -rf /var/lib/apt/lists/*

ENV PATH /var/www/node_modules/.bin:$PATH

COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# add custom php-fpm pool settings, these get written at entrypoint startup
ENV FPM_PM_MAX_CHILDREN=20 \
    FPM_PM_START_SERVERS=2 \
    FPM_PM_MIN_SPARE_SERVERS=1 \
    FPM_PM_MAX_SPARE_SERVERS=3



COPY docker-php-entrypoint /usr/bin/
RUN dos2unix /usr/bin/docker-php-entrypoint \
    && chmod +x /usr/bin/docker-php-entrypoint


COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./nginx/nginx-site.conf /etc/nginx/conf.d/default.conf
COPY ./nginx/dev-cert.pem /etc/nginx/ssl/cert.crt
COPY ./nginx/dev-key.pem /etc/nginx/ssl/key.pem

COPY ./config/opcache.ini $PHP_INI_DIR/conf.d/
COPY ./config/php.ini $PHP_INI_DIR/


WORKDIR /var/www/app/public
EXPOSE 80 443 9000 9001
ENTRYPOINT ["/usr/bin/docker-php-entrypoint"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]