FROM ubuntu:22.04

ENV MIRROR="mirrors.ocf.berkeley.edu"
ENV RUBY_MAJOR 3.3
ENV RUBY_VERSION 3.3.5
ENV RUBY_DOWNLOAD_SHA256 3781a3504222c2f26cb4b9eb9c1a12dbf4944d366ce24a9ff8cf99ecbce75196
ENV RUBYGEMS_VERSION 3.5.16
ENV LIBSODIUM_VERSION 1.0.20
ENV DEBIAN_FRONTEND=noninteractive

# Update & install dependencies
RUN sed -i "s|deb.debian.org|$MIRROR|g" /etc/apt/sources.list \
  && apt-get update && apt-get -y upgrade \
  && apt-get install -y --no-install-recommends \
    bzip2 ca-certificates openssl curl libffi-dev libssl-dev \
    libyaml-dev libxml2 libxml2-dev libpq-dev libxslt1-dev \
    procps zlib1g-dev libjemalloc-dev imagemagick build-essential \
    autoconf bison gcc libbz2-dev libgdbm-dev libglib2.0-dev \
    libncurses-dev libreadline-dev libxslt-dev make ruby \
    software-properties-common unzip wget\
  && rm -rf /var/lib/apt/lists/*

# Configure Ruby
RUN mkdir -p /usr/local/etc && echo 'install: --no-document' >> /usr/local/etc/gemrc \
  && echo 'update: --no-document' >> /usr/local/etc/gemrc

# Download & compile Ruby
RUN curl -fsSL "https://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" -o ruby.tar.gz \
  && echo "$RUBY_DOWNLOAD_SHA256 ruby.tar.gz" | sha256sum -c - \
  && mkdir -p /usr/src/ruby \
  && tar -xzf ruby.tar.gz -C /usr/src/ruby --strip-components=1 \
  && rm ruby.tar.gz \
  && cd /usr/src/ruby \
  && autoconf && ./configure --with-jemalloc --disable-install-doc \
  && make -j"$(nproc)" && make install \
  && rm -rf /usr/src/ruby \
  && gem update --system $RUBYGEMS_VERSION

# Set up Bundler
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" BUNDLE_BIN="$GEM_HOME/bin"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" && chmod 777 "$GEM_HOME" "$BUNDLE_BIN"
RUN gem install bundler -v 2.5.20

# Install Node.js, Yarn, PostgreSQL Client
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
  && curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" | tee /etc/apt/sources.list.d/PostgreSQL.list \
  && wget https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  && apt-key add ACCC4CF8.asc \

  && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgreskey.gpg \
  && apt-get update \
  && apt-get install -y --no-install-recommends nodejs yarn postgresql-17 \
  && rm -rf /var/lib/apt/lists/*

# Install libsodium
RUN curl -fsSL "https://download.libsodium.org/libsodium/releases/libsodium-${LIBSODIUM_VERSION}.tar.gz" -o libsodium.tar.gz \
  && mkdir -p /usr/local/src/libsodium \
  && tar -xzf libsodium.tar.gz -C /usr/local/src/libsodium --strip-components=1 \
  && rm libsodium.tar.gz \
  && cd /usr/local/src/libsodium \
  && ./configure && make -j"$(nproc)" && make install \
  && rm -rf /usr/local/src/libsodium

# Install AWS CLI
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && ./aws/install \
  && rm -rf awscliv2.zip aws
