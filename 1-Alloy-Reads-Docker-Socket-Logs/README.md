# Part 1: Alloy Reads - Docker Socket Logs

Alloy is the first step, it allows us to take a log file, or a unix socket, read from it, and transform it, before sending it off for log ingestion and storage.


* * *

## 0). Be Sure You've Setup the Lab Environment

Be sure you have copied the required files from the previous step in the github repo.

If you have not yet, please setup the lab enviornment.

- Run: `1_permissions_init_for_project.sh`

- Edit: `.env`

- Edit: `./traefik/traefik.yml`

- Review: `docker network`


* * *

## 1). Alloy Access to Docker Socket

First, to get Alloy to read all the logs in docker, you must give it access to the docker socket.

* * *

You can add the Alloy container to the docker socket in your `docker-compose.yml` file using a volume mount. 

Here's how to modify your `docker-compose.yml`:

```yaml
alloy:
  image: grafana/alloy:latest
  volumes:
    - "/var/run/docker.sock:/var/run/docker.sock:ro"
```

Don't forget to also mount the Docker socket (`/var/run/docker.sock`) as a **read-only** volume so Alloy can only access Docker's API to read container logs.


* * *

## 2). Get Alloy to Discover Docker Containers

Let's look at how reading docker logs works in our `config.alloy` file.

In the `config.alloy` file, we will start with container discovery. 

The Docker socket is a Unix socket that allows processes to communicate with the Docker daemon, and Alloy uses this to discover all running containers on your system. 

Here's the discovery block:

```ini
// Discover running Docker containers
discovery.docker "containers" {
    host = "unix:///var/run/docker.sock"
}
```

This connects to Docker and discovers all running containers. 

The exported field `discovery.docker.containers.targets` contains the list of discovered containers.

This is also only possible because of our `docker-compose.yml` file, where we mount the Docker socket into the Alloy container.

You can now view the list of all of your targets and their fields in Alloy:

Access it on the Alloy Web UI: `http://your-alloy-host:12345/component/discovery.docker.containers`

* * *

[Grafana Alloy Docker Discovery Documentation](https://grafana.com/docs/alloy/latest/reference/components/discovery/discovery.docker/)

* * * 


## 3). Use Alloy to Clean Up Labels

Discovering containers is only the first step. 

We need to transform the raw metadata that Docker provides into useful labels that we can query later. 

This is where the relabeling process comes in.

Grafana Alloy's `discovery.relabel` block takes the raw Docker metadata and creates structured labels. For example, Docker provides the container name as `__meta_docker_container_name` with a leading slash, like (`/traefik`). Let's fix that, it's easier to refer to contianers with the `/` removed:

```ini
discovery.relabel "containers" {
    targets = discovery.docker.containers.targets

    rule {
        source_labels = ["__meta_docker_container_name"]
        regex         = "/(.*)"
        target_label  = "container"
    }
}
```

Each `rule` block transforms labels, meaning, each rule transforms Docker's internal metadata into labels you can actually use when searching logs. The regex pattern `/(.*)` captures everything after the leading slash, it strips the leading slash, giving us clean container names. Then the exported field is `discovery.relabel.containers.output`.

You can now view the list of all of your *new* `target_labels` and their fields in Alloy (they will be at the bottom):

Access it: `http://your-alloy-host:12345/component/discovery.relabel.containers#Arguments-rule_0`


* * * 

[Grafana Alloy Discovery Relabeling](https://grafana.com/docs/alloy/latest/reference/components/discovery/discovery.relabel/)

* * * 


## 4). Finish Step 3

Now that you understand the concept, let's clean up the rest of those fields and make them all presentable.

```ini
// Add proper labels to discovered containers
discovery.relabel "containers" {
    targets = discovery.docker.containers.targets

// You should already have this rule in, add the ones under it
    rule {
        source_labels = ["__meta_docker_container_name"]
        regex         = "/(.*)"
        target_label  = "container"
    }
    rule {
        source_labels = ["__meta_docker_container_log_stream"]
        target_label  = "stream"
    }
    rule {
        source_labels = ["__meta_docker_container_id"]
        target_label  = "container_id"
    }
}
```

This block accepts the list of discovered Docker targets from the previous component (`discovery.docker.containers.targets`).

Docker setups with Promtail (now Alloy) often export the label, `container`, as it is a longstanding convention for the raw container name (e.g., "Plex"),

But, `service_name` is gaining traction for Kubernetes or multi-service setups.

You will see both `container` and `service_name` labels from `__meta_docker_container_name`. This is for maximum Grafana dashboard compatibility.

This ensures your logs arrive in Loki/Grafana with standard, readable tags like `container` and `container_id` rather than obscure internal variables.


* * *

### Put a Filter in Your Rules (optional)

This is an example. If you had a container you didnt want to include in the logs, you can add a rule to drop specific containers.

```ini
rule {
  source_labels = ["__meta_docker_container_name"]
  regex         = "noisy_container_.*"
  action        = "drop"
}
```

* * *


## 5). Alloy Send Logs to Collector

Finally, the actual log collection happens through the `loki.source.docker` block. Alloy's configuration component takes the discovered targets and begins streaming their logs from the discovered containers to Loki. It acts as a bridge, reading lines as they are written and immediately pushing them to the `loki.write.local` component.

```ini
// Scrape logs from Docker containers - send to local
loki.source.docker "docker_logs" {
    host       = "unix:///var/run/docker.sock"
    targets    = discovery.relabel.containers.output
    forward_to = [loki.write.local.receiver]
}
```

Notice how the targets come from our relabeling output, `discovery.relabel.containers`. This means every log line will automatically have the labels we configured.


* * *

## 6). Alloy Sends to Local Loki

Let's tie together how logs actually flow from Alloy to Loki. 

We've seen how Alloy collects logs from Docker, but the final step is writing them to Loki for storage and querying.

The final destination for logs is Loki and the `loki.write` component, it points to Loki's endpoint address. This creates an input point (specifically `loki.write.local.receiver`) that other components in the configuration can forward their log data to.

```ini
loki.write "local" {
    endpoint {
        url = "http://loki:3100/loki/api/v1/push"
    }
}
```


* * *

[Grafana Alloy has documentation on using Docker as a Loki Source](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.docker/)

* * *
