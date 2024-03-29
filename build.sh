#!/bin/bash

set -o pipefail -e -u -x

cd $(readlink -f ${0%/*})

GO_AGENT_VERSION=23.3.0
GO_AGENT_VERSION_FULL=${GO_AGENT_VERSION}-16991
DOCKER_IMAGE="local/gocd-elastic-agent:v${GO_AGENT_VERSION}-1"

## Download agent prereq files
for f in docker-entrypoint.sh agent-bootstrapper-logback-include.xml agent-launcher-logback-include.xml agent-logback-include.xml; do
  [[ -f "$f" ]] || curl -sSL https://raw.githubusercontent.com/gocd/docker-gocd-agent-ubuntu-22.04/master/$f > $f
  [[ "${f##*.}" == "sh" && ! -x "$f" ]] && chmod +x "$f"
done

docker build \
    --no-cache \
    --build-arg GO_AGENT_VERSION=$GO_AGENT_VERSION \
    --build-arg GO_AGENT_VERSION_FULL=$GO_AGENT_VERSION_FULL \
    -t $DOCKER_IMAGE \
    .

# List image in docker
docker images $DOCKER_IMAGE

[[ -f push-to-registries.sh ]] && . push-to-registries.sh
