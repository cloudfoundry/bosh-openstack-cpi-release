FROM ubuntu:14.04

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y \
    curl wget tar make uuid-runtime \
    sqlite3 libsqlite3-dev \
    mysql-client libmysqlclient-dev \
    postgresql-9.3 postgresql-client-9.3 libpq-dev \
    build-essential checkinstall \
    libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev \
    libyaml-dev jq; \
    apt-get clean

# install python from source
RUN CURRENT=$PWD && \
    cd /usr/src && \
    wget https://www.python.org/ftp/python/2.7.12/Python-2.7.12.tgz &&\
    tar xzf Python-2.7.12.tgz && \
    cd Python-2.7.12 && \
    ./configure && \
    make install && \
    cd $CURRENT

RUN python -m ensurepip && pip install pytz && pip install python-openstackclient==3.17.0 && \
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
    sudo make install && \
    rm -rf /tmp/ruby-install

#Ruby
RUN ruby-install --system ruby 2.4.0

#Bundler
RUN ["/bin/bash", "-l", "-c", "gem install bundler -v 1.16.5 --no-ri --no-rdoc"]

#BOSH GO CLI
RUN wget https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-5.4.0-linux-amd64 -O /usr/local/bin/bosh-go
RUN chmod +x /usr/local/bin/bosh-go

# receipt generator
RUN cd /tmp && \
    curl -o certify-artifacts -L https://s3.amazonaws.com/bosh-certification-generator-releases/certify-artifacts-linux-amd64 && \
    chmod +x certify-artifacts && \
    mv certify-artifacts /bin/certify-artifacts

#GitHub CLI
RUN cd /tmp && \
    curl -L https://github.com/github/hub/releases/download/v2.2.9/hub-linux-amd64-2.2.9.tgz | tar -xz && \
    cp hub-linux-amd64-2.2.9/bin/hub /usr/local/bin && \
    rm -rf /tmp/hub-linux-amd64-2.2.9 && \
    rm -f /tmp/hub-linux-amd64-2.2.9.tgz
