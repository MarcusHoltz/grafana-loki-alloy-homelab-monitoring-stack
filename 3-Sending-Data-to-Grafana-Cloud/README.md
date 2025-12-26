# Part 3: Sending Logs to Grafana Cloud

You can send your data to the cloud for safe-backup, sure.

But the real reason, is Grafana's AI integration to the data. It can craft outliers and alerts with a single prompt.

Want to send data to Grafana Cloud? Alloy makes this easy through its forwarding configuration.

In the `config.alloy` file, you'll see commented-out blocks for Grafana Cloud. The configuration file was designed so you can enable or disable cloud logging simply by uncommenting those specific lines. 

Basic Authentication (User ID + API Key) is also required in the `.env` file.


* * *

If you've never used Grafana Cloud, you need an account. 

And probably a quick introduction, this video shows how to import local to cloud:

[Grafana Learning Journeys: How to Send Logs to Grafana Cloud Using Alloy](https://youtu.be/Xa3mCIdsno4?t=96)

* * *

> In this setup, you'll be sending **ALL** of your logs to the Grafana Cloud. Please be aware, all logs for all containers and all logs being read from all files.


* * *

## 0). Setup Reminder

Dont forget to delete your current working folder, and copy everything again!

```
Create working folder → Copy 0-Setup-Lab-Environment → Add 3-Sending-Data-to-Grafana-Cloud files → Run permissions script → Run docker-compose
```

(Dont delete working folder when moving to **Part 4: Sending Grafana Cloud Metrics**)

* * *

## 1). Create a Grafana Cloud account

You must have an account to use Grafana Cloud, go ahead and sign up now.

- [https://grafana.com/auth/sign-up/create-user](https://grafana.com/auth/sign-up/create-user)


* * *

## 2). After account creation - find details here

You need to create and org/Grafana Cloud stack

You can create a token if you go to this page:

- https://<your_assigned_url>.grafana.net/a/grafana-collector-app/alloy/installation

- Once you create a token, you will see an "Install and run Grafana Alloy" section.

- This has all of your `env_var` in place you need. Copy that and go to the `.env` file. Paste and replace.


* * *

## 3). Add your details assigned to the .env file

You need to enter your username and password for Alloy to be able to export to the cloud.

Again, if using the Grafana Cloud, you will need to uncomment the lines required.

Username and password are stored in an .env file so you never commit those.

```alloy
// loki.write "grafana_cloud" {
//     endpoint {
//         url = env("GCLOUD_HOSTED_LOGS_URL")
//         basic_auth {
//             username = env("GCLOUD_HOSTED_LOGS_ID")
//             password = env("GCLOUD_RW_API_KEY")
//         }
//     }
// }
```

## 4). Uncommenting the cloud endpoint isnt enough! 

You must also add the destination for your `forward_to` lists:

To finish enabling cloud logging, you would uncomment the `grafana_cloud` block above and then add its receiver to your forwarding configurations. 

For example, the Docker logs would be updated from:

```ini
forward_to = [
    loki.write.local.receiver,
]
```

To include both destinations:

```ini
forward_to = [
    loki.write.grafana_cloud.receiver,  # Cloud
    loki.write.local.receiver,          # Local
]
```

This means Alloy sends every log line to multiple destinations simultaneously, **this also goes for your Traefik access logs**.

* * *

# Part 4: Sending Grafana Cloud Metrics

Beyond logs, Alloy can also collect and forward metrics. In our configuration, we're specifically collecting Alloy's own metrics so we can monitor the health of our logging pipeline itself. This self-monitoring is crucial because if your logging system fails, you need to know about it!

(You can use your current,`3-Sending-Data-to-Grafana-Cloud`, working folder)


* * *

## 1). Alloy Exporter for Prometheus

The metrics collection starts with the self-monitoring exporter:

```ini
prometheus.exporter.self "alloy" { }
```

This component exposes **only** Alloy's internal metrics in Prometheus format.


* * *

## 2). Alloy Prometheus Scraper

Next, we configure a scraper on ourself that periodically collects data  metrics from ourself (uncomment to enable):

```ini
alloyprometheus.scrape "alloy" {
    targets         = prometheus.exporter.self.alloy.targets
    scrape_interval = "60s"
    forward_to      = [
        // prometheus.remote_write.grafana_cloud.receiver,
        // prometheus.remote_write.local.receiver,
    ]
}
```

The `scrape_interval` of sixty seconds means Alloy checks its own metrics every minute. 


* * *

## 3). Alloy prom grafana cloud endpoint

In the `config.alloy` file, you'll see commented-out blocks for Grafana Cloud prometheus server. The configuration is designed so you can enable or disable cloud logging simply by uncommenting specific lines. Here's the Grafana Cloud Prometheus endpoint configuration:

You need to enter your username and password.

Username and password are stored in an .env file so you never commit those.


```ini
// prometheus.remote_write "grafana_cloud" {
//     endpoint {
//         url = env("GCLOUD_HOSTED_METRICS_URL")
//         basic_auth {
//             username = env("GCLOUD_HOSTED_METRICS_ID")
//             password = env("GCLOUD_RW_API_KEY")
//         }
//     }
// }
```

Notice the URL is different from the Loki endpoint. 

Grafana Cloud separates logs and metrics into different cloud hosted service enpoint urls, each optimized for its data type. 

The username here is your hosted metrics ID, which is different from your hosted logs ID.


* * *

## 4). Alloy prom local endpoint

If you're running your own Prometheus instance locally, you can uncomment and configure the local endpoint:

```ini
// prometheus.remote_write "local" {
//     endpoint {
//         url = "http://prometheus:9090/api/v1/write"
//     }
// }
```


* * *

## 5). Alloy Sends to Local Loki

Now that we're out of the cloud, let's tie together - how logs actually flow from Alloy to Loki, one more time.

We've seen how Alloy collects logs from Docker and files, but the final step is writing them to Loki for storage and querying.

The final destination for logs is Loki and the `loki.write` component, it points to Loki's endpoint address.

```ini
loki.write "local" {
    endpoint {
        url = "http://loki:3100/loki/api/v1/push"
    }
}
```

## 6). Loki Collection Endpoint - IP or DNS

This is optional choice is configured in the docker-compose file.

You can set the IP address to match to a static IP assigned in the `docker-compose.yml`, like the config above, let the internal Docker DNS hostname resolution handle it. **Make sure you have loki as the container name, or use a static IP**

```yaml
loki:
  image: grafana/loki:latest
  container_name: loki
  ports:
    - "3100:3100"
  networks:
    br1.232:
      ipv4_address: 10.236.232.146
```

- Using a static IP on a Docker network makes the configuration more predictable. You could also use the container name `loki` instead of the IP.

- Port 3100 inside the container to port 3100 on the Docker network. 

- When Alloy sends logs to Loki, it's not just sending raw text. Remember all those labels we created during discovery and processing? Alloy bundles those labels with each log line, and Loki indexes them.

* * *

[Grafana Alloy Loki Write endpoint documentation](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.write/)

* * *
