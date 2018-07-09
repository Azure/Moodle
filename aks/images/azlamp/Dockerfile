FROM ubuntu:16.04

MAINTAINER hoson@microsoft.com

RUN sed -i "s://archive\.ubuntu\.com/://azure.archive.ubuntu.com/:" /etc/apt/sources.list && \
    apt update && apt upgrade -y && \
    apt install -y rsync apache2 libapache2-mod-php \
        php php-cli php-curl php-zip php-pear php-mbstring php-dev mcrypt \
        graphviz aspell php-soap php-json php-redis php-bcmath php-gd php-pgsql php-mysql \
        php-xmlrpc php-intl php-xml php-bz2

COPY init_container.sh /usr/local/bin/

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/init_container.sh"]
