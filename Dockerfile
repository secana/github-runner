FROM ubuntu:20.04

ENV GITHUB_PAT ""
ENV GITHUB_OWNER ""
ENV GITHUB_REPOSITORY ""
ENV RUNNER_WORKDIR "_work"
ENV RUNNER_LABELS ""

ENV DOCKER_BUCKET get.docker.com
ENV DOCKER_VERSION 20.10.7

ENV DOTNET_SDK_VERSION=5.0

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin

RUN apt-get update \
    && apt-get install -y \
	apt-utils \
        curl \
        sudo \
        git \
        jq \
        iputils-ping \
        unzip \
        wget \
	nodejs \
	npm \
	apt-utils \
	pkg-config \
	openssl \
	libssl-dev \
	zip \
	libc6 \
	libgcc1 \
	libicu66 \
	clang \
	lld \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m github \
    && usermod -aG sudo github \
    && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Upgrade NPM
RUN npm install npm@latest -g

# Install Docker
RUN ARCH=$(lscpu | grep Architecture | tr -d ' ' | cut -d : -f 2) \
        && set -x \
        && curl -fSL "https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
        && tar -xzvf docker.tgz \
        && mv docker/* /usr/local/bin/ \
        && rmdir docker \
        && rm docker.tgz \
        && docker -v

# Install .NET 5
RUN wget https://dot.net/v1/dotnet-install.sh \
	&& chmod u+x dotnet-install.sh
RUN ./dotnet-install.sh -c ${DOTNET_SDK_VERSION} -InstallDir /usr/share/dotnet/ \
	&& ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet
	
# Install github runner
USER github
WORKDIR /home/github

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y --default-toolchain=stable
ENV PATH="$HOME/.cargo/bin:${PATH}"
RUN $HOME/.cargo/bin/cargo install sccache
ADD ./config /home/github/.cargo/config

RUN ARCH=$(lscpu | grep Architecture | tr -d ' ' | cut -d : -f 2) \
        && if [ $ARCH != "aarch64" ]; then ARCH=x64; else ARCH=arm64; fi \
        && GITHUB_RUNNER_VERSION=$(curl --silent "https://api.github.com/repos/actions/runner/releases/latest" | jq -r '.tag_name[1:]') \
    && curl -Ls https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-linux-${ARCH}-${GITHUB_RUNNER_VERSION}.tar.gz | tar xz \
    && sudo ./bin/installdependencies.sh

COPY --chown=github:github entrypoint.sh runsvc.sh ./
RUN sudo chmod u+x ./entrypoint.sh ./runsvc.sh

ENTRYPOINT ["/home/github/entrypoint.sh"]
