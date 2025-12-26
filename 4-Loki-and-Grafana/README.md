# Part 5: Loki the endpoind

Loki also goes by the collector, the compressor, the reciever, the accepter, the listener, etc. It has a lot of things it does, but is still very easy to use. 

Loki takes logs.

(You can use your current working folder, all deployment configurations have the same loki file)


* * *

## 1). How Loki Sets Where It's Listening

Moving to the Loki side of our stack, we need to configure where Loki accepts incoming logs. This is defined in the `loki-config.yaml` file under the server section:

```yaml
server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  http_server_read_timeout: 5s
  http_server_write_timeout: 10s
  log_level: info
```

- The `http_listen_port` of `3100` is the standard Loki port and matches what we configured in Alloy. Loki actually exposes multiple endpoints on this port. The `/loki/api/v1/push` endpoint that Alloy uses is for writing logs, while `/loki/api/v1/query` and `/loki/api/v1/query_range` are for reading logs (which Grafana uses).

- The `grpc_listen_port` on port `9096` and is used forfor internal gRPC communication, which some clients use instead of HTTP. In our simple setup, we're not using it, but it's available if needed.

- The `http_server_read_timeout` limits how long Loki waits to receive the complete request, protecting against slow clients. 

- The `http_server_write_timeout` limits how long Loki spends sending a response, preventing queries that take too long from tying up resources.


* * *

[Loki Server Configuration Documentation](https://www.google.com/search?q=https://grafana.com/docs/loki/latest/configure/server/)

* * *


## 2). Loki Docker Compose Volumes

Loki's storage configuration determines everything from where log data lives to how it's organized and accessed.

In this section we'll look at file storage for loki logs.


### Configuring Loki Data on the Host

Loki has to store this data somewhere, if you dump it all in docker volume  - I will cry.

Please dont make me cry, please export this data for the host system to have available.

* * *

In our `docker-compose.yml`, we **mount a host directory** to persist this data, but we need to amke sure to keep permissions correct:

```yaml
volumes:
  - "./loki/data:/loki"
  - "./loki/config:/etc/loki"
```

This means all the log data written to `/loki` inside the container is actually stored in `./loki/data` on your host machine. If the Loki container restarts, your logs are safe because they're outside the container filesystem.


* * *

### Permissions for Loki Data on the Host

Exporting the data above requires correct permissions.

They must be **set for the container**, now that these files reside on the host.

The `1_permissions_init_for_project.sh` script creates and sets proper permissions for these directories:

```bash
LOKI_DATA_DIR="./loki/data"
LOKI_UID=10001
LOKI_GID=10001

mkdir -p "$LOKI_DATA_DIR/rules"
mkdir -p "$LOKI_DATA_DIR/chunks"
mkdir -p "$LOKI_DATA_DIR/wal"

chown -R "$LOKI_UID:$LOKI_GID" "$LOKI_DATA_DIR"
```

Loki runs as user ID `10001` inside the container, so these directories must be owned by that user ID. The script creates the necessary subdirectories and sets ownership before starting Loki for the first time.


* * *

## 3). Loki Log File Storage Location

In our `loki-config.yaml`, the storage configuration uses the filesystem mode:

```yaml
common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
```

- This defines the storage path and tells Loki to store data on the local disk (`filesystem`) inside `/loki/chunks`.

- The `path_prefix` sets the base directory for all Loki data. Within this, we have separate directories for different types of data. 

- The `chunks_directory` is where actual log data gets written. Loki compresses logs into chunks, which are immutable blocks of data that can be efficiently stored and queried.

- `replication_factor: 1` is set because you are running a single instance. It won't try to copy data to other nodes.


* * *

## 4). Loki Log Storage Style

The storage schema configuration tells Loki how to organize this data:

```yaml
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
```

This configuration is particularly important. 

- The `store: tsdb` means Loki uses its Time Series Database index format, which is optimized for time-based queries. 

- The `period: 24h` means Loki creates a new index file every twenty-four hours. This makes it efficient to drop old data and keeps index files at manageable sizes.


* * *

[Lokie Storage Configuration Documentation](https://grafana.com/docs/loki/latest/configure/storage/)

* * *



* * *

## 5). How Loki Keeps Logs

Back to the config file.

Log retention is a balance between storage costs and regulatory or operational requirements.

The retention configuration starts with the compactor:

```yaml
compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
  delete_request_store: filesystem
```

The compactor runs every ten minutes (controlled by `compaction_interval`) and performs two key tasks: 
- It merges small chunks into larger ones for efficiency.
- It deletes old data based on retention rules. 

Just incase there is a problem the `retention_delete_delay` of two hours provides a safety buffer.
- When the compactor marks data for deletion, it waits two hours before actually removing it, giving you time to recover if you realize you need that data.


* * *

## 6). How Long Loki Keeps Logs

The actual retention period is set in the limits configuration:

```yaml
limits_config:
  retention_period: 720h  # 30 days
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

The `retention_period` of 720 hours means thirty days. 

**Any logs older than this will be deleted during compaction.**

The `reject_old_samples` setting prevents clients from writing logs with timestamps older than `reject_old_samples_max_age` (one week). 

**This protects against scenarios where a log collector has been offline and tries to push a huge backlog of old logs all at once.**

- Logs older than 30 days are deleted
- Compactor runs every 10 minutes
- 2-hour safety buffer before actual deletion
- Rejects logs older than 7 days at ingestion


* * *

[Loki Retention Documentation](https://grafana.com/docs/loki/latest/operations/storage/retention/)

* * *


## 7). Loki Operational Limits

This provides stability for loki, and ensures that one noisy container (spamming logs) cannot take down the entire logging system.

These limits also control resource usage:

```yaml
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
  max_query_series: 100000
  max_query_parallelism: 32
```

- The ingestion rate, `ingestion_rate_mb: 10`, caps the incoming log volume at 10 Megabytes per second. This limits how fast logs can be written, preventing a single container from overwhelming Loki. 

- The `max_query_series` stops users from running massive queries (like "show me all logs for all time") that would crash the server by consuming all resources.

- These are reasonable defaults, but you may need to adjust them based on your log volume and query patterns.

* * *

## 8). Loki with GeoIP data

We're collecting labels from Docker, from Traefik access logs, and potentially from GeoIP lookups.
The default Loki limits are quite restrictive, so we've increased them to accommodate our rich labeling strategy. 

```yaml
  max_label_names_per_series: 30
  max_label_name_length: 1024
  max_label_value_length: 2048
```

- By increasing `max_label_names_per_series` to 30, you enable the complex parsing in Alloy. Defaults are often too low for this.

- The `max_label_...` settings are tuned up to allow for rich metadata (like long URLs, complex User-Agents, or GeoIP data) without truncation errors.

Without these increased limits, Loki would reject logs that have too many labels or labels that are too long.

* * *

[Loki Limits Documentation](https://www.google.com/search?q=https://grafana.com/docs/loki/latest/configure/limits_config/)

* * *


## Additional Fixes That Might Be Useful

Here are some adustments you can make to your `loki-config.yaml`, if your setup requires it:


- If you have high traffic, you might need to bump `ingestion_rate_mb` to 50 or 100 to avoid "429 Too Many Requests" errors.

- You can add `query_timeout: 1m` here to automatically kill dashboard queries that hang for too long.


* * *

# Part 6: Grafana Configuration

Are we there yet? No, so if you have to use the bathroom we can make a quick stop now.


(You can use your current working folder, all deployments have at least one Grafana dashboard)


* * *

## 1). How Grafana Looks for Datasources

When Grafana starts, it needs to know where to find its data sources like Loki. Rather than configuring these manually through the UI, we use Grafana's provisioning system to automatically configure datasources when the container starts.

In our `docker-compose.yml`, we mount a provisioning directory into Grafana:

```yaml
volumes:
  - "./grafana/provisioning/:/etc/grafana/provisioning"
```

Grafana looks for YAML files in specific subdirectories under `/etc/grafana/provisioning`. The structure follows a convention:

```
/etc/grafana/provisioning/
  ├── datasources/
  ├── dashboards/
  ├── notifiers/
  ├── alerting/
  └── plugins/
```

Each subdirectory corresponds to a different type of Grafana configuration. When Grafana starts, it scans these directories and automatically provisions whatever it finds. This is incredibly powerful for infrastructure-as-code approaches because your Grafana configuration lives in version control alongside your application code.

The environment variables in Grafana's configuration also prepare it for this:

```yaml
environment:
  - GF_PATHS_PROVISIONING=/etc/grafana/provisioning
```

This tells Grafana where to look for provisioning files. Although this is the default location, setting it makes the configuration clearer and easier to troubleshoot with docker volume mounts.

Grafana's provisioning system watches these directories every 10 second and will reload when a file changes, no need to  restart the container.


* * *

## 2). How Grafana Finds Loki and Sets the UID

The datasource configuration is where Grafana learns how to connect to Loki. Our configuration lives in `ds.yaml`:

```yaml
apiVersion: 1
datasources:
- name: Loki
  type: loki
  uid: lokithedatasourceuid
  access: proxy 
  orgId: 1
  url: http://loki:3100
  basicAuth: false
  isDefault: true
  version: 1
  editable: false
```

Let's break down each field. The `name` is what appears in Grafana's datasource dropdown. The `type: loki` tells Grafana this is a Loki datasource, which determines what query interface Grafana shows and how it communicates with the backend.

The `uid` (unique identifier) is particularly important. This identifier is used in dashboard JSON definitions to reference this specific datasource. If you import a dashboard that was built against a Loki datasource with UID `lokithedatasourceuid`, Grafana will automatically connect the dashboard panels to this datasource. This makes dashboards portable across Grafana instances.

The `url` points to Loki's HTTP API at our static IP and port. The `access: proxy` setting means Grafana acts as a proxy for queries. When you view a dashboard, your browser sends queries to Grafana, and Grafana forwards them to Loki. This is better than direct access because it means Loki doesn't need to be accessible from users' browsers, and Grafana can cache and optimize queries.

The `isDefault: true` setting makes this the default datasource for new panels. When you create a new panel in a dashboard, it automatically selects this Loki instance. The `editable: false` setting prevents users from modifying this datasource through the UI, which helps maintain consistency in production environments.

This datasource file needs to be placed in the correct location for Grafana to find it. Based on our docker-compose configuration, it should be at:

```
./grafana/provisioning/datasources/ds.yaml
```

When Grafana starts, it reads this file and automatically creates the datasource connection to Loki. You'll see it immediately available in the datasource list without any manual configuration.


* * *

## 3). How Grafana Provisions Dashboards

Dashboards are the visual interface where you query and display your logs. Like datasources, dashboards can be provisioned automatically using configuration files.

The dashboard provisioning configuration is in `dashboard.yaml`:

```yaml
apiVersion: 1
providers:
  - name: "default"
    orgId: 1
    folder: ""
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards
```

This configuration creates a provider that tells Grafana to look for dashboard JSON files in the specified path. The `type: file` means dashboards are loaded from files on disk rather than from a database or API.

The `updateIntervalSeconds: 10` setting is interesting. Grafana checks this directory every ten seconds for new or modified dashboard files. This means you can drop a new dashboard JSON file into the directory, and within ten seconds, it appears in Grafana without restarting anything.

The `disableDeletion: false` setting allows dashboards to be deleted through the UI. If this were true, any dashboard from this provider would be read-only and couldn't be deleted, which is useful in production environments where you want to prevent accidental deletion of important dashboards.

The `folder: ""` setting means dashboards appear at the root level of Grafana's dashboard list. You could set this to a folder name like "Production Monitoring" to organize dashboards automatically.

To actually provision dashboards, you would place JSON files in the configured path. Based on our docker-compose volumes, that would be:

```
./grafana/provisioning/dashboards/
```

Any JSON file you place there gets loaded as a dashboard. Dashboard JSON files can be exported from Grafana's UI or created programmatically. They're large JSON documents that describe every panel, query, and visualization in the dashboard.

Here's what makes this powerful: you can version control your dashboards alongside your application code. When you deploy a new version of your application, you can deploy updated dashboards at the same time. The dashboards automatically reference our Loki datasource by its UID, so everything connects seamlessly.

* * *

## 4). Adding New Dashboards

You can always [search for Grafana Dashboards](https://grafana.com/grafana/dashboards/) that other's have made public. No support provided.

You can edit:

- Name: `Container Log Dashboard`

- Folder: `Dashboards`

- Unique identifier (UID): `ghNnYnbt`

You **must** edit:

- Loki: `Select a Loki data source`

- `Import`

