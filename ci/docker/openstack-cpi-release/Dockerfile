FROM ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV BOSH_CLI_VERSION=7.10.10

RUN apt-get -y update \
    && apt-get install -y --no-install-recommends \
        locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

# ruby needed for BATS (bosh-acceptance-tests is an RSpec suite)
RUN apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    git-lfs \
    jq \
    openssh-client \
    ruby \
    ruby-bundler \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://github.com/cloudfoundry/bosh-cli/releases/download/v${BOSH_CLI_VERSION}/bosh-cli-${BOSH_CLI_VERSION}-linux-amd64" \
    > /usr/bin/bosh \
    && chmod +x /usr/bin/bosh \
    && cp /usr/bin/bosh /usr/local/bin/bosh-go
