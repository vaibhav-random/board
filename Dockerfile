FROM alpine:3.11 AS build
RUN apk add -u --no-cache npm php7

WORKDIR /code

COPY package.json .

RUN npm install -g grunt
RUN npm install

COPY .sandstorm/ .sandstorm/
COPY .tx/ .tx/
COPY docs/ docs/
COPY Jelastic/ Jelastic/
COPY build/ build/
COPY client/ client/
COPY docker-scripts/nginx.conf restyaboard.conf
COPY sql/ sql/
COPY api_explorer/ api_explorer/
COPY server/ server/
COPY media/ media/
COPY .codeclimate.yml .
COPY .htaccess .
COPY diagnose.php .
COPY ejabberd.yml .
COPY restyaboard.sh .
COPY restyaboard-ssl.conf .
COPY restyaboard_uninstall.sh .
COPY Gruntfile.js .

RUN npm run docker:prebuild


FROM alpine:3.11

# update & install package
RUN apk add -u --no-cache \
    bash \
    curl \
    # imagemagick is heavy. Adds a couple of MB to the image
    imagemagick \
    jq \
    msmtp \
    nginx \
    php7 \
    php7-curl \
    php7-fpm \
    php7-imagick \
    php7-imap \
    php7-json \
    php7-ldap \
    php7-mbstring \
    php7-pdo_pgsql \
    php7-pgsql \
    php7-xml \
    postgresql-client \
    unzip \
    tzdata                                                && \
    sed -i 's/nobody/nginx/g' /etc/php7/php-fpm.d/www.conf    && \
    echo 'sendmail_path = /usr/bin/msmtp -t' > /etc/php7/php.ini && \
    rm /etc/nginx/conf.d/default.conf                       

# after initial setup of deps to improve rebuilding speed
ENV ROOT_DIR=/var/lib/nginx/html \
    CONF_FILE=/etc/nginx/conf.d/restyaboard.conf \
    SMTP_DOMAIN=localhost \
    SMTP_USERNAME=root \
    SMTP_PASSWORD=root \
    SMTP_SERVER=localhost \
    SMTP_PORT=465 \
    TZ=Etc/UTC

# deploy app
COPY --from=build /code/restyaboard-docker.zip /tmp/restyaboard.zip
RUN unzip /tmp/restyaboard.zip -d ${ROOT_DIR} && \
    rm /tmp/restyaboard.zip && \
    chown -R nginx:nginx ${ROOT_DIR}

# install apps
ADD docker-scripts/install_apps.sh /tmp/
RUN chmod +x /tmp/install_apps.sh
RUN . /tmp/install_apps.sh && \
    chown -R nginx:nginx ${ROOT_DIR}

# configure app
WORKDIR ${ROOT_DIR}
RUN cp restyaboard.conf ${CONF_FILE} && \
    sed -i "s/server_name.*$/server_name \"localhost\";/" ${CONF_FILE} && \
    sed -i "s|listen 80.*$|listen 80;|" ${CONF_FILE} && \
    sed -i "s|root.*html|root ${ROOT_DIR}|" ${CONF_FILE}

# entrypoint
COPY docker-scripts/docker-entrypoint.sh /

# Default values. Can be changed during container start.
ENV POSTGRES_HOST=postgres \
    POSTGRES_PORT=5432 \
    POSTGRES_USER=admin \
    POSTGRES_PASSWORD=admin \
    POSTGRES_DB=restyaboard

RUN chmod +x /docker-entrypoint.sh
RUN chmod +x server/php/shell/main.sh

# TODO root user should be avoided but required for now

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]