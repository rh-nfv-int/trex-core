# SPDX-License-Identifier: BSD-3-Clause
# Multi-stage build for the TRex traffic generator, running the server in
# interactive mode. The build is fully reproducible from the source tree and
# lays out /trex as a flat, self-contained tree like the official TRex binary
# releases (https://trex-tgn.cisco.com/trex/release/).

ARG UBUNTU_VERSION=22.04

# --------------------------------------------------------------------------
# Build stage: compile TRex from source with the bundled DPDK and assemble a
# flat, self-contained runtime tree in /trex.
# --------------------------------------------------------------------------
FROM ubuntu:${UBUNTU_VERSION} AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		g++ \
		gcc \
		libarchive-dev \
		libibverbs-dev \
		libmnl-dev \
		libnuma-dev \
		librdmacm-dev \
		make \
		pciutils \
		pkg-config \
		python3 \
		rdma-core \
		zlib1g-dev \
	&& rm -rf /var/lib/apt/lists/*

COPY . /opt/trex-core
WORKDIR /opt/trex-core/linux_dpdk

# --no-ofed-check builds the mlx5 PMD against upstream rdma-core (no Mellanox
# OFED). --with-archive enables libarchive support required to load the ice
# firmware DDP packages. --no-old skips the PIE variants we do not ship.
RUN ./b configure --no-ofed-check --with-archive \
	&& ./b build --no-old

# Assemble the flat runtime tree. scripts/ holds relative symlinks into the
# build output; dereferencing them yields a self-contained /trex. Drop the
# debug binary and the dangling optional-feature links first, then strip.
RUN cd /opt/trex-core \
	&& rm -f scripts/_t-rex-64-debug \
	&& find scripts -xtype l -delete \
	&& cp -RL scripts /trex \
	&& rm -rf /trex/so/aarch64 /trex/so/ppc64le /trex/so/x86_64/*-debug.so \
	&& strip /trex/_t-rex-64 \
	&& find /trex/so/x86_64 -name '*.so*' -exec strip {} +

# Default configuration, overridable by mounting a volume on /etc/trex_cfg.yaml.
RUN echo '- version: 2' > /etc/trex_cfg.yaml

# --------------------------------------------------------------------------
# Runtime stage: just the release tree and its runtime dependencies.
# --------------------------------------------------------------------------
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		catatonit \
		gawk \
		ibverbs-providers \
		iproute2 \
		kmod \
		libarchive13 \
		libibverbs1 \
		libmnl0 \
		libnuma1 \
		librdmacm1 \
		netbase \
		pciutils \
		procps \
		python3 \
		zlib1g \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=builder /trex /trex

VOLUME /etc/trex_cfg.yaml

EXPOSE 4500 4501 4502 4511

ENV PYTHONPATH=/trex/automation/trex_control_plane/interactive

WORKDIR /trex

ENTRYPOINT ["/usr/bin/catatonit", "--", "/trex/_t-rex-64", "-i", "--no-scapy-server"]
CMD ["--stl"]
