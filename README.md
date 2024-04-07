Docker container to run Mikrotik RouterOS

### Usage

```
docker build -t routeros https://github.com/stasjok/docker-routeros.git
docker run -d --rm \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -p 2222:22   \
  -p 443:443 \
  -p 8291:8291 \
  -p 8728:8728 \
  -p 8729:8729 \
  --name routeros-$(head -c 4 /dev/urandom | xxd -p)-$(date +'%Y%m%d-%H%M%S') \
  routeros
```

docker-compose

```
version: "3"

services:
  routeros:
    image: routeros:latest
    build:
      context: https://github.com/stasjok/docker-routeros.git
      # Override RouterOS version
      # args:
      #   ROUTEROS_VERSION: 7.12.2
    restart: unless-stopped
    environment:
      NUM_INTERFACES: 4
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
      - /dev/kvm
    ports:
      - "443:443"
      - "8291:8291"
      - "8728:8728"
      - "8729:8729"
```

### Notes

Now you can connect to your RouterOS container via SSH (on 2222 port) or WinBox.

## List of exposed ports

| Description | Ports |
|-------------|-------|
| Defaults    | 21, 22, 23, 80, 443, 8291, 8728, 8729 |
| IPSec       | 50, 51, 500/udp, 4500/udp |
| OpenVPN     | 1194/tcp, 1194/udp |
| L2TP        | 1701 |
| PPTP        | 1723 |

## Links

- https://github.com/vaerh/docker-routeros
- https://github.com/EvilFreelancer/docker-routeros
- https://github.com/joshkunz/qemu-docker
- https://github.com/ennweb/docker-kvm
