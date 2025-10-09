ARG UBUNTU_VERSION="24.04"
FROM ubuntu:${UBUNTU_VERSION}

ARG UBUNTU_VERSION
ENV DOCKER_CHANNEL=stable \
    DOCKER_VERSION=28.3.3 \
    DOCKER_COMPOSE_VERSION=v2.39.2 \
    BUILDX_VERSION=v0.26.1 \
    DEBUG=false

# Install common dependencies
RUN set -eux; \
    apt-get update && apt-get install -y \
    ca-certificates wget curl iptables supervisor \
    && rm -rf /var/lib/apt/lists/*

# Set iptables-legacy for Ubuntu 22.04 and newer
RUN set -eux; \
    if [ "${UBUNTU_VERSION}" != "20.04" ]; then \
    update-alternatives --set iptables /usr/sbin/iptables-legacy; \
    fi

# Install Docker and buildx
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) dockerArch='x86_64' ; buildx_arch='linux-amd64' ;; \
        armhf) dockerArch='armel' ; buildx_arch='linux-arm-v6' ;; \
        armv7) dockerArch='armhf' ; buildx_arch='linux-arm-v7' ;; \
        aarch64) dockerArch='aarch64' ; buildx_arch='linux-arm64' ;; \
        *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;; \
    esac && \
    wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz" && \
    tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin/ && \
    rm docker.tgz && \
    wget -O docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.${buildx_arch}" && \
    mkdir -p /usr/local/lib/docker/cli-plugins && \
    chmod +x docker-buildx && \
    mv docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx && \
    dockerd --version && \
    docker --version && \
    docker buildx version

COPY modprobe start-docker.sh entrypoint.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh

RUN chmod +x /usr/local/bin/start-docker.sh \
    /usr/local/bin/entrypoint.sh \
    /usr/local/bin/modprobe

VOLUME /var/lib/docker

# Install Docker Compose
RUN set -eux; \
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    docker-compose version && \
    ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose


# Install utilidades auxiliares
RUN set -eux; \
    apt-get update && apt-get install -y \
    git htop tmux python3-pip vim \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install kind
RUN set -eux; \
    if [ "$(uname -m)" = "x86_64" ]; then \
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-arm64; \
    fi && \
    chmod +x ./kind && \
    mv ./kind /usr/local/bin/kind

# Install kubectl
RUN set -eux; \
    if [ "$(uname -m)" = "x86_64" ]; then \
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"; \
    fi && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# Install k9s
RUN curl -sS https://webinstall.dev/k9s | bash

# Install k3d
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

RUN set -eux; \
    apt-get update && apt-get install -y \
    kubecolor net-tools iputils-ping sudo\
    && rm -rf /var/lib/apt/lists/*


# Instalar nvm y Node.js
ENV NVM_DIR /root/.nvm
ENV NODE_VERSION v22.18.0  # Especifica la versión exacta que deseas

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    nvm use default

    
ENTRYPOINT ["entrypoint.sh"]
CMD ["bash"]
