FROM ubuntu:20.04

LABEL description="GoCD agent based on Ubuntu version 20.04" \
  maintainer="Revomatico <infra@revomatico.com>" \
  url="https://www.gocd.org"

ADD https://github.com/krallin/tini/releases/download/v0.18.0/tini-static-amd64 /usr/local/sbin/tini

# force encoding
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8
ENV GO_JAVA_HOME="/gocd-jre"
ENV GO_AGENT_ZIP=/tmp/go-agent.zip
ENV DEBIAN_FRONTEND=noninteractive

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
  apt-get install -y --no-install-recommends software-properties-common gnupg ca-certificates git openssh-client bash unzip curl locales procps sysvinit-utils coreutils && \
  ## Add docker repo
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
  add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
  ## Install additional packages
  apt-get install -y --no-install-recommends docker-ce-cli libxml2-utils jq python3-pip && \
  apt-get autoclean && \
  echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && /usr/sbin/locale-gen && \
  curl --fail --location --silent --show-error 'https://github.com/AdoptOpenJDK/openjdk15-binaries/releases/download/jdk-15.0.2%2B7/OpenJDK15U-jre_x64_linux_hotspot_15.0.2_7.tar.gz' --output /tmp/jre.tar.gz && \
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
  ## Install ansible and deps
  pip3 install -U setuptools setuptools_rust && \
  pip3 install -U wheel && \
  pip3 install -U 'ansible==2.9.25' && \
  pip3 install --force-reinstall 'Jinja2==2.11.3' && \
  ## Download additional tools
  curl --fail --location --silent --show-error https://github.com/antonmedv/fx/releases/download/20.0.2/fx-linux.zip > /tmp/fx-linux.zip && \
  unzip /tmp/fx-linux.zip fx-linux && \
  mv fx-linux /usr/local/bin/fx && \
  rm -vf /tmp/fx-linux.zip && \
  curl --fail --location --silent --show-error https://github.com/mikefarah/yq/releases/download/v4.12.1/yq_linux_amd64 > /usr/local/bin/yq && \
  chmod +x /usr/local/bin/*

ADD docker-entrypoint.sh /


# ensure that logs are printed to console output
COPY --chown=go:root agent-bootstrapper-logback-include.xml agent-launcher-logback-include.xml agent-logback-include.xml /go-agent/config/

RUN chown -R go:root /docker-entrypoint.d /go /godata /docker-entrypoint.sh \
    && chmod -R g=u /docker-entrypoint.d /go /godata /docker-entrypoint.sh


ENTRYPOINT ["/docker-entrypoint.sh"]

USER go