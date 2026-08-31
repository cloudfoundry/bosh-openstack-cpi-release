FROM ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV BOSH_CLI_VERSION=7.10.10

RUN apt-get -y update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        git-lfs \
        jq \
        locales \
        openssh-client \
        ruby \
        ruby-bundler \
        ruby-dev \
    && locale-gen en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://github.com/cloudfoundry/bosh-cli/releases/download/v${BOSH_CLI_VERSION}/bosh-cli-${BOSH_CLI_VERSION}-linux-amd64" \
    > /tmp/bosh \
    && echo "ff092e567f6b6b41cbcaf8b4065eb2bae29a7463f537bd99ae6424c0d93291c9  /tmp/bosh" | sha256sum -c - \
    && mv /tmp/bosh /usr/bin/bosh \
    && chmod +x /usr/bin/bosh \
    && cp /usr/bin/bosh /usr/local/bin/bosh-go
