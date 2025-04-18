FROM ubuntu:18.04

LABEL Name="dCache"
LABEL Version="v1"
WORKDIR /dcache

ENV DEBIAN_FRONTEND=noninteractive 
ENV DCACHE_DB_PASSWORD=dcachepass
ENV pgver=13

RUN apt-get update && \
    apt-get install -y \
    wget \
    tar \
    apt-utils \
    locales \
    openssh-client rsyslog apache2-utils\
    iputils-ping \
    telnet
# Download and extract OpenJDK 21
RUN wget https://download.java.net/openjdk/jdk21/ri/openjdk-21+35_linux-x64_bin.tar.gz -O /tmp/openjdk.tar.gz && \
    mkdir -p /opt/java/openjdk-21 && \
    tar -xzf /tmp/openjdk.tar.gz -C /opt/java/openjdk-21 --strip-components=1 && \
    rm /tmp/openjdk.tar.gz

# Set environment variables
ENV JAVA_HOME=/opt/java/openjdk-21
ENV PATH=$JAVA_HOME/bin:$PATH
ENV JAVA_OPTS="-Djava.net.preferIPv4Stack=true"

RUN apt-get update && \
    apt-get install -y curl software-properties-common && \
    curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    add-apt-repository "deb https://apt-archive.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" && \
    apt-get update && \
    apt-get install -y postgresql-${pgver} postgresql-client-${pgver}

COPY chimera-init.sh /chimera-init.sh
RUN chmod +x /chimera-init.sh

RUN wget https://www.dcache.org/old/downloads/1.9/repo/10.2/dcache_10.2.10-1_all.deb
RUN dpkg -i dcache_10.2.10-1_all.deb || (apt-get update && apt-get install -f -y)
RUN rm dcache_10.2.10-1_all.deb


# Configuration files
COPY config/dcache.conf /etc/dcache/dcache.conf
COPY config/mylayout.conf /etc/dcache/layouts/mylayout.conf
COPY config/gplazma.conf /etc/dcache/gplazma.conf
COPY config/multi-mapfile /etc/dcache/multi-mapfile
COPY config/ban.conf /etc/dcache/ban.conf
RUN mkdir -p /etc/grid-security && mkdir -p /etc/grid-security/certificates
COPY config/storage-authzdb /etc/grid-security/storage-authzdb

# Configure PostgreSQL
RUN service postgresql start && \
    su - postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD 'postgrespass';\"" && \
    su - postgres -c "psql -c \"CREATE USER dcache WITH LOGIN CREATEDB PASSWORD 'dcachepass';\"" && \
    su - postgres -c "createdb -O dcache chimera" && \
    # Update pg_hba.conf
    echo "local all postgres md5" > /etc/postgresql/${pgver}/main/pg_hba.conf && \
    echo "host all all 127.0.0.1/32 md5" >> /etc/postgresql/${pgver}/main/pg_hba.conf && \
    echo "host all all ::1/128 md5" >> /etc/postgresql/${pgver}/main/pg_hba.conf && \
    echo "local all all md5" >> /etc/postgresql/${pgver}/main/pg_hba.conf && \
    echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/${pgver}/main/pg_hba.conf && \
    # Update postgresql.conf
    echo "listen_addresses = '*'" >> /etc/postgresql/${pgver}/main/postgresql.conf && \
    echo "ssl = off" >> /etc/postgresql/${pgver}/main/postgresql.conf && \
    service postgresql restart


# Configure dcache database connection with SSL disabled
RUN echo "chimera.db.url=jdbc:postgresql://localhost/chimera?ssl=false" >> /etc/dcache/dcache.conf && \
    echo "chimera.db.user=dcache" >> /etc/dcache/dcache.conf && \
    echo "chimera.db.password=dcachepass" >> /etc/dcache/dcache.conf


ENV ZOOKEEPER_HOST=zookeeper
# Pool service configuration
RUN { echo "dcache.zookeeper.connection = ${ZOOKEEPER_HOST}:2181"; \
    cat /etc/dcache/layouts/mylayout.conf; } > /tmp/mylayout.conf.tmp && \
    mv /tmp/mylayout.conf.tmp /etc/dcache/layouts/mylayout.conf


# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2181 2288 11111

CMD ["/entrypoint.sh"]
