FROM ubuntu:22.04

LABEL description="GoCD agent based on Ubuntu version 22.04" \
  maintainer="Revomatico <infra@revomatico.com>" \
  url="https://www.gocd.org"

ADD https://github.com/krallin/tini/releases/download/v0.19.0/tini-static-amd64 /usr/local/sbin/tini

# force encoding
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    GO_JAVA_HOME="/gocd-jre" \
    GO_AGENT_ZIP=/tmp/go-agent.zip \
    DEBIAN_FRONTEND=noninteractive \
    YQ_VERSION=v4.34.1 \
    FX_VERSION=24.1.0 \
    NERDCTL_VERSION=1.4.0 \
    BUILDKIT_VERSION=v0.11.6

ARG UID=1000
ARG GID=1000
ARG GO_AGENT_VERSION
ARG GO_AGENT_VERSION_FULL

RUN \
# add mode and permissions for files we added above
  chmod 0755 /usr/local/sbin/tini && \
  chown root:root /usr/local/sbin/tini && \
# add our user and group first to make sure their IDs get assigned consistently,
# regardless of whatever dependencies get added
# add user to root group for gocd to work on openshift
  useradd -u ${UID} -g root -d /home/go -m go && \
  apt-get update && \
  ## Handle TZData non interactive installl
  ln -fs /usr/share/zoneinfo/Europe/Bucharest /etc/localtime && \
  apt-get install -y --no-install-recommends software-properties-common gnupg ca-certificates git openssh-client bash unzip curl locales procps sysvinit-utils coreutils sudo && \
  ## Install additional packages
  apt-get install -y --no-install-recommends libxml2-utils jq && \
  apt-get autoclean && \
  echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && /usr/sbin/locale-gen && \
  curl -sL https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
  curl --fail --location --silent --show-error 'https://github.com/adoptium/temurin16-binaries/releases/download/jdk-16.0.2%2B7/OpenJDK16U-jdk_x64_linux_hotspot_16.0.2_7.tar.gz' --output /tmp/jre.tar.gz && \
  mkdir -p /gocd-jre && \
  tar -xf /tmp/jre.tar.gz -C /gocd-jre --strip 1 && \
  rm -rf /tmp/jre.tar.gz && \
  mkdir -p /docker-entrypoint.d /go /godata && \
  ## Download the gocd agent
  curl --fail --location --silent --show-error "https://download.gocd.org/binaries/${GO_AGENT_VERSION_FULL}/generic/go-agent-${GO_AGENT_VERSION_FULL}.zip" > ${GO_AGENT_ZIP} && \
  unzip ${GO_AGENT_ZIP} -d / && \
  rm -vf ${GO_AGENT_ZIP} && \
  mv /go-agent-* /go-agent && \
  chown -R ${UID}:0 /go-agent && \
  chmod -R g=u /go-agent && \
  ## Download additional tools
  set -x && \
  ## fx
  curl --fail --location --silent --show-error https://github.com/antonmedv/fx/releases/download/$FX_VERSION/fx_linux_arm64 > /usr/local/bin/fx && \
  ## yq
  curl --fail --location --silent --show-error https://github.com/mikefarah/yq/releases/download/$YQ_VERSION/yq_linux_amd64 > /usr/local/bin/yq && \
  ## nerdctl
  curl --fail --location --silent --show-error https://github.com//containerd/nerdctl/releases/download/v$NERDCTL_VERSION/nerdctl-$NERDCTL_VERSION-linux-amd64.tar.gz | \
    tar -C /usr/local/bin --strip-components 0 --wildcards -xzvf - && \
    ln -s /usr/local/bin/nerdctl /usr/local/bin/docker && \
  ## buildkit
  curl --fail --location --silent --show-error https://github.com/moby/buildkit/releases/download/$BUILDKIT_VERSION/buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz | \
    tar -C /usr/local/bin --strip-components 1 --wildcards -xzvf - '*/build*' && \
    rm -f /usr/local/bin/buildkit-qemu* && \
  chmod +x /usr/local/bin/* && \
  ## Add go to sudoers
  echo "go ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/go


ADD docker-entrypoint.sh /


# ensure that logs are printed to console output
COPY --chown=go:root agent-bootstrapper-logback-include.xml agent-launcher-logback-include.xml agent-logback-include.xml /go-agent/config/

RUN chown -R go:root /docker-entrypoint.d /go /godata /docker-entrypoint.sh \
    && chmod -R g=u /docker-entrypoint.d /go /godata /docker-entrypoint.sh


ENTRYPOINT ["/docker-entrypoint.sh"]

USER go
