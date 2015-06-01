FROM ubuntu:14.04

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get update
RUN apt-get -y upgrade; apt-get clean

RUN apt-get install -y git curl wget tar make; apt-get clean

# chruby
RUN mkdir /tmp/chruby
RUN cd /tmp && curl https://codeload.github.com/postmodern/chruby/tar.gz/v0.3.9 | tar -xz
RUN cd /tmp/chruby-0.3.9 && sudo ./scripts/setup.sh
RUN rm -rf /tmp/chruby

# ruby-install
RUN mkdir /tmp/ruby-install
RUN cd /tmp && curl https://codeload.github.com/postmodern/ruby-install/tar.gz/v0.5.0 | tar -xz
RUN cd /tmp/ruby-install-0.5.0 && sudo make install
RUN rm -rf /tmp/ruby-install

#default ruby
RUN ruby-install ruby 2.1.2
RUN cp /etc/profile.d/chruby.sh /etc/profile.d/chruby-with-ruby-2.1.2.sh
RUN echo "chruby 2.1.2" >> /etc/profile.d/chruby-with-ruby-2.1.2.sh

#Bundler
RUN ["/bin/bash", "-l", "-c", "gem install bundler --no-ri --no-rdoc"]

#BOSH CLI
RUN ["/bin/bash", "-l", "-c", "gem install bosh_cli --no-ri --no-rdoc"]
