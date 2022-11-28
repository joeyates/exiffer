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
RUN curl -O https://packages.erlang-solutions.com/erlang/debian/pool/erlang-base_24.2-1~debian~buster_amd64.deb
RUN curl -O https://packages.erlang-solutions.com/erlang/debian/pool/erlang-ssl_24.2-1~debian~buster_amd64.deb
RUN curl -O https://packages.erlang-solutions.com/erlang/debian/pool/erlang-crypto_24.2-1~debian~buster_amd64.deb
RUN curl -O https://packages.erlang-solutions.com/erlang/debian/pool/erlang-public-key_24.2-1~debian~buster_amd64.deb
RUN curl -O https://packages.erlang-solutions.com/erlang/debian/pool/erlang-asn1_24.2-1~debian~buster_amd64.deb
RUN curl -O https://packages.erlang-solutions.com/erlang/debian/pool/erlang-syntax-tools_24.2-1~debian~buster_amd64.deb
RUN curl -O https://packages.erlang-solutions.com/erlang/debian/pool/erlang-inets_24.2-1~debian~buster_amd64.deb
RUN curl -O https://packages.erlang-solutions.com/erlang/debian/pool/erlang-mnesia_24.2-1~debian~buster_amd64.deb
RUN curl -O https://packages.erlang-solutions.com/erlang/debian/pool/erlang-runtime-tools_24.2-1~debian~buster_amd64.deb
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

COPY ../lib /app/
COPY ../mix.* /app/

RUN apt install -y build-essential
RUN mix deps.get
RUN mix release
