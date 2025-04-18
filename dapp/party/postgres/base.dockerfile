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

RUN wget https://download.java.net/openjdk/jdk21/ri/openjdk-21+35_linux-x64_bin.tar.gz -O /tmp/openjdk.tar.gz && \
    mkdir -p /opt/java/openjdk-21 && \
    tar -xzf /tmp/openjdk.tar.gz -C /opt/java/openjdk-21 --strip-components=1 && \
    rm /tmp/openjdk.tar.gz

ENV JAVA_HOME=/opt/java/openjdk-21
ENV PATH=$JAVA_HOME/bin:$PATH
ENV JAVA_OPTS="-Djava.net.preferIPv4Stack=true"

RUN apt-get update && \
    apt-get install -y curl software-properties-common && \
    curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    add-apt-repository "deb https://apt-archive.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" && \
    apt-get update && \
    apt-get install -y postgresql-${pgver} postgresql-client-${pgver}

RUN wget https://www.dcache.org/old/downloads/1.9/repo/10.2/dcache_10.2.10-1_all.deb
RUN dpkg -i dcache_10.2.10-1_all.deb || (apt-get update && apt-get install -f -y)
RUN rm dcache_10.2.10-1_all.deb

# Configure PostgreSQL
RUN service postgresql start && \
    su - postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD 'let-me-in';\"" && \
    su - postgres -c "psql -c \"CREATE USER dcache WITH LOGIN CREATEDB PASSWORD 'let-me-in';\"" && \
    su - postgres -c "createdb -O dcache chimera" && \
    # Update pg_hba.conf
    echo "local all postgres md5" > /etc/postgresql/${pgver}/main/pg_hba.conf && \
    echo "host all all 127.0.0.1/32 md5" >> /etc/postgresql/${pgver}/main/pg_hba.conf && \
    echo "host all all ::1/128 md5" >> /etc/postgresql/${pgver}/main/pg_hba.conf && \
    echo "local all all md5" >> /etc/postgresql/${pgver}/main/pg_hba.conf && \
    echo "hostnossl all all 0.0.0.0/0 md5" >> /etc/postgresql/${pgver}/main/pg_hba.conf && \
    # Update postgresql.conf
    echo "listen_addresses = '*'" >> /etc/postgresql/${pgver}/main/postgresql.conf && \
    echo "ssl = off" >> /etc/postgresql/${pgver}/main/postgresql.conf && \
    service postgresql restart

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2181 2288 11111

CMD ["/entrypoint.sh"]
