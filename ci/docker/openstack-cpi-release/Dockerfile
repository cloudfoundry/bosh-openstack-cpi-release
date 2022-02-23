FROM ubuntu:focal

ENV bosh_cli_version 6.4.15
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
    libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev \
    whois \
    libyaml-dev jq && \
    apt-get clean


# install python from source
RUN CURRENT=$PWD && \
    cd /usr/src && \
    wget https://www.python.org/ftp/python/2.7.16/Python-2.7.16.tgz && \
    tar xzf Python-2.7.16.tgz && \
    cd Python-2.7.16 && \
    ./configure && \
    make install && \
    cd $CURRENT

RUN python -m ensurepip && pip install pytz && pip install pyrsistent==0.16.1 python-openstackclient==3.19.0 && \
    pip install awscli==1.19.112

# install newest git CLI
RUN apt-get install software-properties-common -y; \
    add-apt-repository ppa:git-core/ppa -y; \
    apt-get update; \
    apt-get install git -y

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
RUN \
  wget --quiet https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${bosh_cli_version}-linux-amd64 --output-document="/usr/bin/bosh" && \
  chmod +x /usr/bin/bosh && \
  cp /usr/bin/bosh /usr/local/bin/bosh-go && \
  chmod +x /usr/local/bin/bosh-go

#GitHub CLI
RUN cd /tmp && \
    curl -L https://github.com/github/hub/releases/download/v2.14.2/hub-linux-amd64-2.14.2.tgz | tar -xz && \
    cp hub-linux-amd64-2.14.2/bin/hub /usr/local/bin && \
    rm -rf /tmp/hub-linux-amd64-2.14.2 && \
    rm -f /tmp/hub-linux-amd64-2.14.2.tgz
