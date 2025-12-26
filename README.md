# Homelab Guide to Monitoring Docker Logs and Log Files

![Grafana Alloy Loki on Docker for Homelab Monitoring With A Farmer](https://raw.githubusercontent.com/MarcusHoltz/marcusholtz.github.io/main/assets/img/header/header--grafana--alloy-loki-stack-docker-homelab-monitoring.jpg)

When you're running containerized applications, you need to understand what's happening inside your stack. 

This article was written to help you get better understanding of logging and observability.

If you want to try this out yourself on system prepared for you, check out the free labs available for Grafana at [killercoda.com](https://killercoda.com/het-tanis/course/Linux-Labs/102-monitoring-linux-logs).

There are plenty more examples than this one, for more check out the [alloy-scenarios git repo](https://github.com/grafana/alloy-scenarios).


* * *

## Homelab Monitoring Stack: Alloy, Loki, and Grafana

This article uses three tools for monitoring:

- `Grafana Alloy` for log collection
- `Loki` for log storage
- `Grafana` for visualization

By the end of this guide, you'll understand what each part does.

**BONUS**: `Traefik` is also used in this stack.


* * *

## Quick Start

Traefik + Loki + Grafana Cloud on macvlan networking. DNS-01 ACME via Cloudflare.

Configure `.env` and `traefik.yml`, create the macvlan network, then follow the incremental lab steps  →  

- [0-Setup-Lab-Environment](https://github.com/MarcusHoltz/grafana-loki-alloy-docker-demo/tree/main/0-Setup-Lab-Environment)

- [1-Alloy-Reads-Docker-Socket-Logs](https://github.com/MarcusHoltz/grafana-loki-alloy-docker-demo/tree/main/1-Alloy-Reads-Docker-Socket-Logs)

- [2-Alloy-Reads-Files-Traefik-Access-Logs](https://github.com/MarcusHoltz/grafana-loki-alloy-docker-demo/tree/main/2-Alloy-Reads-Files-Traefik-Access-Logs)

- [3-Sending-Data-to-Grafana-Cloud](https://github.com/MarcusHoltz/grafana-loki-alloy-docker-demo/tree/main/3-Sending-Data-to-Grafana-Cloud)

- [4-Loki-and-Grafana](https://github.com/MarcusHoltz/grafana-loki-alloy-docker-demo/tree/main/4-Loki-and-Grafana)

- [5-Lyrion-Airsonic-Grafana-Alerts](https://github.com/MarcusHoltz/grafana-loki-alloy-docker-demo/tree/main/5-Lyrion-Airsonic-Grafana-Alerts)

* * *

### The Complete Alloy, Loki, and Grafana Stack

1. **Container logs to Docker** → Docker daemon captures them
2. **Alloy discovers containers** → Via Docker socket
3. **Alloy applies labels** → Container name, stream, etc.
4. **Alloy tails Traefik logs** → Parses JSON, adds labels
5. **Alloy sends to Loki** → HTTP push to port 3100
6. **Loki indexes and stores** → Labels + compressed chunks
7. **Grafana queries Loki** → LogQL queries via provisioned datasource
8. **Compactor manages retention** → Deletes logs older than 30 days

