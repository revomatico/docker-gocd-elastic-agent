#!/bin/bash

set -o pipefail -e -u -x

cd $(readlink -f ${0%/*})

GO_AGENT_VERSION=22.3.0
GO_AGENT_VERSION_FULL=${GO_AGENT_VERSION}-15301
DOCKER_IMAGE="local/gocd-elastic-agent:v${GO_AGENT_VERSION}-2"

## Download agent prereq files
for f in docker-entrypoint.sh agent-bootstrapper-logback-include.xml agent-launcher-logback-include.xml agent-logback-include.xml; do
  [[ -f "$f" ]] || curl -sSL https://raw.githubusercontent.com/gocd/docker-gocd-agent-ubuntu-22.04/master/$f > $f
  [[ "${f##*.}" == "sh" && ! -x "$f" ]] && chmod +x "$f"
done

docker build \
    --build-arg GO_AGENT_VERSION=$GO_AGENT_VERSION \
    --build-arg GO_AGENT_VERSION_FULL=$GO_AGENT_VERSION_FULL \
    -t $DOCKER_IMAGE \
    .

# List image in docker
docker images $DOCKER_IMAGE

[[ -f push-to-registries.sh ]] && . push-to-registries.sh
