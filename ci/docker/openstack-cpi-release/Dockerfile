FROM ubuntu:jammy

ENV bosh_cli_version 7.7.2
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && apt-get install -y locales && locale-gen en_US.UTF-8
RUN update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

RUN apt-get install -y \
    sudo \
    apt-utils \
    curl wget tar make uuid-runtime \
    sqlite3 libsqlite3-dev \
    mysql-client libmysqlclient-dev \
    postgresql postgresql-client libpq-dev \
    build-essential checkinstall \
    libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev \
    whois \
    netcat \
    python3 \
    python3-pip \
    libyaml-dev jq && \
    apt-get clean

RUN pip3 install pytz && pip3 install pyrsistent python-openstackclient && \
    pip3 install awscli

# install newest git CLI
RUN apt-get install software-properties-common -y; \
    add-apt-repository ppa:git-core/ppa -y; \
    apt-get update; \
    apt-get install -y git git-lfs

# ruby-install
RUN mkdir /tmp/ruby-install && \
    cd /tmp/ruby-install && \
    curl https://codeload.github.com/postmodern/ruby-install/tar.gz/v0.8.3 | tar -xz && \
    cd /tmp/ruby-install/ruby-install-0.8.3 && \
    make install && \
    rm -rf /tmp/ruby-install

#Ruby
RUN ruby-install --system ruby 3.1.0

#BOSH CLI
RUN curl -sL https://github.com/cloudfoundry/bosh-cli/releases/download/v${bosh_cli_version}/bosh-cli-${bosh_cli_version}-linux-amd64 \
    > /usr/bin/bosh \
    && chmod +x /usr/bin/bosh && \
    cp /usr/bin/bosh /usr/local/bin/bosh-go

#GitHub CLI
RUN cd /tmp && \
    curl -L https://github.com/github/hub/releases/download/v2.14.2/hub-linux-amd64-2.14.2.tgz | tar -xz && \
    cp hub-linux-amd64-2.14.2/bin/hub /usr/local/bin && \
    rm -rf /tmp/hub-linux-amd64-2.14.2 && \
    rm -f /tmp/hub-linux-amd64-2.14.2.tgz
