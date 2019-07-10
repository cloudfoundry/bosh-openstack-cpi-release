FROM ubuntu:16.04

RUN apt-get -y update && apt-get install -y locales && locale-gen en_US.UTF-8
RUN update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

RUN apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y \
    apt-utils \
    curl wget tar make uuid-runtime \
    sqlite3 libsqlite3-dev \
    mysql-client libmysqlclient-dev \
    postgresql-9.5 postgresql-client-9.5 libpq-dev \
    build-essential checkinstall \
    libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev \
    libyaml-dev jq; \
    apt-get clean


# install python from source
RUN CURRENT=$PWD && \
    cd /usr/src && \
    wget https://www.python.org/ftp/python/2.7.16/Python-2.7.16.tgz &&\
    tar xzf Python-2.7.16.tgz && \
    cd Python-2.7.16 && \
    ./configure && \
    make install && \
    cd $CURRENT

RUN python -m ensurepip && pip install pytz && pip install python-openstackclient==3.19.0 && \
    pip install awscli

# install newest git CLI
RUN apt-get install software-properties-common -y; \
    add-apt-repository ppa:git-core/ppa -y; \
    apt-get update; \
    apt-get install git -y

# ruby-install
RUN mkdir /tmp/ruby-install && \
    cd /tmp/ruby-install && \
    curl https://codeload.github.com/postmodern/ruby-install/tar.gz/v0.6.1 | tar -xz && \
    cd /tmp/ruby-install/ruby-install-0.6.1 && \
    make install && \
    rm -rf /tmp/ruby-install

#Ruby
RUN ruby-install --system ruby 2.4.6

#Bundler
RUN ["/bin/bash", "-l", "-c", "gem install bundler -v 1.16.6 --no-ri --no-rdoc"]

#BOSH GO CLI
RUN wget https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-5.5.1-linux-amd64 -O /usr/local/bin/bosh-go
RUN chmod +x /usr/local/bin/bosh-go

#GitHub CLI
RUN cd /tmp && \
    curl -L https://github.com/github/hub/releases/download/v2.12.1/hub-linux-amd64-2.12.1.tgz | tar -xz && \
    cp hub-linux-amd64-2.12.1/bin/hub /usr/local/bin && \
    rm -rf /tmp/hub-linux-amd64-2.12.1 && \
    rm -f /tmp/hub-linux-amd64-2.12.1.tgz
