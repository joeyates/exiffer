# Build a release using an older Linux
# so the executable depends on an older
# (and more widely available GLibC version)

FROM debian:buster-slim

# Set up workspace
WORKDIR /app

# curl
RUN apt update
RUN apt install -y curl

# Install Erlang
RUN apt install -y libncurses5 procps
ENV ERLANG_URL=https://packages.erlang-solutions.com/erlang/debian/pool
ENV ERTS_RELEASE=24.3.3-1
ENV ERTS_PLATFORM=debian~buster_amd64
ENV PACKAGE=$ERTS_RELEASE~$ERTS_PLATFORM.deb
RUN curl -O $ERLANG_URL/erlang-base_$PACKAGE
RUN curl -O $ERLANG_URL/erlang-ssl_$PACKAGE
RUN curl -O $ERLANG_URL/erlang-crypto_$PACKAGE
RUN curl -O $ERLANG_URL/erlang-public-key_$PACKAGE
RUN curl -O $ERLANG_URL/erlang-asn1_$PACKAGE
RUN curl -O $ERLANG_URL/erlang-syntax-tools_$PACKAGE
RUN curl -O $ERLANG_URL/erlang-inets_$PACKAGE
RUN curl -O $ERLANG_URL/erlang-mnesia_$PACKAGE
RUN curl -O $ERLANG_URL/erlang-runtime-tools_$PACKAGE
RUN dpkg -i *.deb

# Install Elixir
RUN apt install -y unzip locales
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
RUN locale-gen
RUN mkdir elixir
RUN curl --output elixir/elixir-v1.14.2-otp-24.zip https://repo.hex.pm/builds/elixir/v1.14.2-otp-24.zip
RUN (cd elixir; unzip elixir-v1.14.2-otp-24.zip)
ENV PATH="${PATH}:/app/elixir/bin"
ENV LC_ALL=en_US.UTF-8
RUN mix local.hex --force

# Prepare build
RUN apt install -y build-essential zstd

# Copy code
COPY ../mix.* /app/
COPY ../lib /app/lib/

# Prepare build
RUN mix deps.get
