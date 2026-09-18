# TRex container image

`Dockerfile` (at the repository root) builds a self-contained image that runs
the TRex server in interactive mode. It is published to
`ghcr.io/<owner>/trex` by the `container` GitHub workflow on every push.

## Build locally

    podman build -t trex:local -f Dockerfile .

## Configuration

The default config `/etc/trex_cfg.yaml` (see `docker/trex_cfg.yaml`) is a
placeholder. Provide your own by mounting a volume on that path:

    -v /etc/trex/trex_cfg.yaml:/etc/trex_cfg.yaml:ro

or point TRex at a different file by appending `--cfg /path/to/file` to the
`run` command. Set the `interfaces:` list to the PCI addresses of the DPDK
devices passed to the container.

## Devices and hugepages

Like any DPDK application, the container needs hugepages and access to the NIC
devices. Bind the devices to `vfio-pci` (or another DPDK-compatible driver) on
the host first, then run privileged with the relevant paths mounted:

    podman run -it --rm --privileged \
        -v /dev/hugepages:/dev/hugepages \
        -v /dev/vfio:/dev/vfio \
        -v /sys/bus/pci:/sys/bus/pci \
        -v /lib/modules:/lib/modules:ro \
        -v /etc/trex/trex_cfg.yaml:/etc/trex_cfg.yaml:ro \
        ghcr.io/<owner>/trex:latest

The default command is `--stl` (stateless). Override it to change the mode or
add flags, e.g. advanced stateful mode:

    podman run ... ghcr.io/<owner>/trex:latest --astf

Mellanox/NVIDIA NICs use the `mlx5` driver and do not need `vfio-pci`; the
device stays bound to `mlx5_core` and its `/dev/infiniband` must be exposed
(`--device /dev/infiniband`).
