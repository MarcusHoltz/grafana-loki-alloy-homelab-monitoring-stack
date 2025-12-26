# Part 2: Alloy Reads - Files (Traefik Access Logs)


Beyond container stdout and stderr logs, we often need to collect structured application logs from files. In this example, we're using Traefik as a reverse proxy.

Traefik will write access logs in JSON format to a file. This gives us rich information about every HTTP request hitting our infrastructure.


* * *


## 0). Quick Reminder: Working Folder Setup

1. Delete your current working folder

2. Create a new working folder

3. Copy `0-Setup-Lab-Environment` into it

4. Add `2-Alloy-Reads-Files-Traefik-Access-Logs` files

5. Run `1_permissions_init_for_project.sh`

6. Run `docker-compose up -d`


When moving to the next step - delete the working folder and repeat this process.

* * *

## 1). Docker - Traefik Mount for Access Logs

In the `docker-compose.yml` file, there needs to be a section to tell Traefik to export logs to the host so we can read them outside of the container.

You will find `"./traefik/access-logs:/opt/access-logs"` in your `docker-compose.yml` file that send our logs to our current directory under `traefik` and inside of `access-logs`.

```yaml
  traefik:
    image: traefik:latest
    container_name: traefik
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./traefik/access-logs:/opt/access-logs"
```


* * *


## 2). Traefik Config - Access Logs Type and Location

In your static `traefik.yml` config, you will need to be sure you're passing the same path, and telling what kind of log format you need.


```yaml
################################################################
# Access Logging
################################################################
accessLog:
  filePath: "/opt/access-logs/access.json"
  format: json
  fields:
    defaultMode: keep
    headers:
      defaultMode: keep
      names:
        User-Agent: keep
        Referer: keep
        Forwarded: keep
```


* * *

## 3). Alloy Docker Volume to Access Traefik Logs in Alloy

This snippet from the `docker-compose.yml` file creates a target pointing to the access log file. 

In the `docker-compose.yml`, mount the Traefik access logs directory into the Alloy container so it can read these files:

```yaml
alloy:
  image: grafana/alloy:latest
  volumes:
  - "./traefik/access-logs:/var/log:ro"
```


* * *

## 4). Access the Access Logs in Alloy

In the `config.alloy` file, the process of reading file-based logs is slightly different from reading Docker logs. 

First, we need to tell Alloy where to find the log files. The `local.file_match` component generates a target for our file discovery:

```ini
local.file_match "traefik_access_logs" {
    path_targets = [{
        __path__ = "/var/log/access.json",
    }]
}
```

This creates a target, `traefik_access_logs`, pointing to Traefik's JSON access log file that we mounted as a volume from our host to our Alloy container.

* * *

[Grafana Alloy local file documentation](https://grafana.com/docs/alloy/latest/reference/components/local/local.file_match/)

* * *


## 5). Read the File In

Once Alloy knows where the file is, the `loki.source.file` component can begin tailing it, similar to how the `tail -f` command works:

```ini
loki.source.file "traefik_access" {
    targets    = local.file_match.traefik_access_logs.targets
    forward_to = [loki.process.traefik_labels.receiver]
}
```

Our new Loki file source, `traefik_access`, tails the file and forwards new lines to `traefik_labels` for processing, the next stage in the pipeline - `loki.process` acts as a middleware layer that modifies the log metadata before storage.

Notice that instead of forwarding directly to Loki, we're forwarding to that `loki.process` processing stage first. This is because Traefik's JSON logs contain structured data that we want to extract into labels for Loki.

* * *

[Grafana Alloy Loki Source File Documentation](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.file/)

* * *


## 6). Parse JSON and Add Labels

The `loki.process` block below parses the JSON and creates labels. Traefik writes fields like ClientHost, RequestMethod, and DownstreamStatus in its JSON logs, and we want these as queryable labels in Loki:

```ini
// Add labels to Traefik access logs - send raw JSON to Loki
loki.process "traefik_labels" {
    forward_to = [loki.write.local.receiver]

// Drop the filename label (not needed with single file)
stage.label_drop {
    values = ["filename"]
}

// Add a static label so dashboard queries work
    stage.static_labels {
        values = {
            host     = "localhost",
            job      = "traefik",
            log_type = "access",
        }
    }
}

```

In the block above,

- We are forwarding `traefik_labels` - which was first assigned from our local file match, `traefik_access_logs`, with output delivered to us from `traefik_access`, then forwarded onto the `loki.process`, `traefik_labels`, above.

- `stage.label_drop` Removes the `filename` label to reduce index cardinality.

- `stage.static_labels` adds static labels to identify these as Traefik access logs. 


* * *

- [local.file_match](https://grafana.com/docs/alloy/latest/reference/components/local/local.file_match/)

- [loki.source.file](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.file/)

- [loki.process](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.process/)

* * *


## You now have file logs and socket logs

One detail to note: the forward configuration, `forward_to`, appears in multiple places because we have multiple sources. 

Both Docker logs and Traefik logs ultimately forward to `loki.write.local.receiver`. 

This receiver has `local` in it because you can change where logs go by modifying just the `loki.write` block, and all your sources automatically use the new destination.
