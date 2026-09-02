FROM ubuntu:noble

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV BOSH_CLI_VERSION=7.10.10

RUN apt-get -y update \
    && apt-get install -y --no-install-recommends \
        locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

RUN apt-get install -y --no-install-recommends \
    bison \
    ca-certificates \
    curl \
    build-essential \
    git \
    git-lfs \
    jq \
    libffi-dev \
    libgdbm-dev \
    libncurses-dev \
    libreadline-dev \
    libssl-dev \
    libyaml-dev \
    netcat-openbsd \
    zlib1g-dev \
    openssh-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ruby-install: compile Ruby 3.4 from source so gem versions match the Gemfile.lock
RUN mkdir /tmp/ruby-install && \
    cd /tmp/ruby-install && \
    curl -fsSL https://codeload.github.com/postmodern/ruby-install/tar.gz/v0.9.3 -o ruby-install.tar.gz && \
    echo "3e920c9c770ce040cdf71cc64b809e861b613c570c6113ee61ab1d2885a16ab3  ruby-install.tar.gz" | sha256sum -c - && \
    tar -xz -f ruby-install.tar.gz && \
    cd ruby-install-0.9.3 && \
    make install && \
    rm -rf /tmp/ruby-install

RUN ruby-install --system --no-install-deps ruby 3.4

RUN curl -fsSL "https://github.com/cloudfoundry/bosh-cli/releases/download/v${BOSH_CLI_VERSION}/bosh-cli-${BOSH_CLI_VERSION}-linux-amd64" \
    > /tmp/bosh \
    && echo "ff092e567f6b6b41cbcaf8b4065eb2bae29a7463f537bd99ae6424c0d93291c9  /tmp/bosh" | sha256sum -c - \
    && mv /tmp/bosh /usr/bin/bosh \
    && chmod +x /usr/bin/bosh \
    && cp /usr/bin/bosh /usr/local/bin/bosh-go
