FROM arm32v7/debian:stretch-slim

LABEL maintainer "Clay Shekleton <clay@clayshekleton.com>"

# Based off of https://github.com/hashicorp/docker-consul/blob/master/0.X/Dockerfile

# Version of Consul to download
ENV CONSUL_VERSION=1.0.7

# Create consul user and group
RUN addgroup consul && \
    adduser --system --ingroup consul consul

#ARG DEBIAN_FRONTEND=noninteractive

# Base tool install
RUN apt-get update && \
    apt-get -qy install wget unzip &&  \
    mkdir -p /tmp/build && \
    cd /tmp/build && \
    wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_arm.zip && \
    unzip -d /bin consul_${CONSUL_VERSION}_linux_arm.zip && \
    cd /tmp && \
    rm -rf /tmp/build && \
    rm -rf /var/lib/apt/lists/*

# The /consul/data dir is used by Consul to store state. The agent will be started
# with /consul/config as the configuration directory so you can add additional
# config files in that location.
RUN mkdir -p /consul/data && \
    mkdir -p /consul/config && \
    chown -R consul:consul /consul

# Consul Ports: https://www.consul.io/docs/agent/options.html#ports-used
EXPOSE 8300 8301 8301/udp 8302 8302/udp 8500 8600 8600/udp

USER consul
ENTRYPOINT ["/bin/consul"]