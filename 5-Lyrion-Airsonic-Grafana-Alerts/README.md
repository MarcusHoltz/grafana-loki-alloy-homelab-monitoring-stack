# Part 7: LyrionMediaServer Setup

To demonstrate our monitoring stack in action, we need an application that generates interesting logs. LyrionMediaServer (formerly Logitech Media Server) is a music streaming server that logs every track played, making it perfect for testing our Grafana alerting system.


* * *
## Persistant Data

We are going to keep persistant data inside of ./appdata/<app_name>

* * *

## 0.) Setup Working Folder First

1. Delete your current working folder
2. Create a new working folder
3. Copy `0-Setup-Lab-Environment` into it
4. Add `2-Alloy-Reads-Files-Traefik-Access-Logs` files
5. Run `1_permissions_init_for_project.sh`
6. Run `docker-compose up -d`

When moving to the next part - delete the working folder and repeat this process.


* * *
## 1). Configure LyrionMediaServer in Docker Compose

The LyrionMediaServer container needs access to your music files and a place to store its configuration. Add this service to your `docker-compose.yml`:


```yaml
---
  lyrionmusicserver:
    image: dlandon/lyrionmusicserver
    container_name: LyrionMusicServer
    ports:
      - "9000:9000"    # Web interface
      - "9090:9090"    # CLI interface
      - "3483:3483"    # SlimProto (TCP)
      - "3483:3483/udp" # SlimProto (UDP)
    env_file:
      - .env
    labels:
      - "traefik.enable=true"
      - "traefik.http.services.lyrionmusicserver.loadbalancer.server.port=9000"
      - "traefik.http.routers.lyrionmusicserver.rule=Host(`lms.${DOMAIN}`) || Host(`lyrion.${SUBDOMAIN}`)"
      - "traefik.http.routers.lyrionmusicserver.entrypoints=websecure"
      - "traefik.http.routers.lyrionmusicserver.tls=true"
      - "traefik.http.routers.lyrionmusicserver.tls.certresolver=cloudflare"
      - "traefik.http.routers.lyrionmusicserver.service=lyrionmusicserver"
      - "traefik.http.routers.lyrionmusicserver.tls.domains[0].sans=*.${DOMAIN}"
      - "traefik.http.routers.lyrionmusicserver.tls.domains[1].sans=*.${SUBDOMAIN}"
    volumes:
      - '${MUSIC_STORAGE}:/music:ro'
      - './appdata/lyrion:/config:rw'
    networks:
      br1.232:
        ipv4_address: 10.236.232.138
```

That was a lot above, what does it all mean:


- Port 9000 is the web interface where you manage your music library

- Ports 3483 (TCP and UDP) are used by Squeezebox clients to connect to the server

- The ipv4_address is set to `10.236.232.138` this is a macvlan address on our host network

- The music directory is mounted as read-only (`:ro`) since the server only needs to read files

- Configuration is stored in `./appdata/lyrion` on your host for persistence



Access the web interface at `http://10.236.232.138:9000` to verify it's running. 
The first-time setup wizard will guide you through adding your music library, located at `/music`.


* * *

## 2). Install the PlayLog Plugin

At time of writing, you will need PlayLog.

This plugin allows you you to log the tracks you listen to, either automatically or by pressing a few remote control buttons. It provides a web interface for viewing its log, linking to the web for more information about what you've listened to, and downloading XML and M3U playlists of played songs.



### Step 1: Install Plugin from Settings

First we need to install PlayLog:

- Click on the menu and find the **Settings** area

- Click on **Server**

- On the new page, click the drop down menu at the top

- Under **plugins** in the drop down menu, find **Manage Plugins**

- Click on **Manage Plugins** in the drop down menu

- Use the **search** field in the upper right corner

- **playlog** should bring up what we need

- Check the box for **PlayLog**

- Click **Save Settings** at the bottom of the page

- Restart the LyrionMediaServer container when prompted



### Step 2: Configure PlayLog

Once the container restarts, go back to Settings > Server:

- In the drop down menu, click **PlayLog settings** (under Plugins section)

- Under **Current Song Logging**, select **All tracks** (every single track played generates a log entry)

- Click **Save Settings**



### Step 3: Enable Debug Logging

To get the detailed log format we need for parsing:

- Go to **Settings** → **Server Settings** → **Logging**

- After clicking on **Logging** in the drop down menu, you should be on a new page.

- Check the box: **Save logging settings for use at next application restart**

- Scroll down to find `(plugin.PlayLog) - PlayLog` in the list

- Change its level from `WARN` to `DEBUG`

- Click **Save Settings**


The PlayLog plugin is now configured and will write play events to the Docker logs.


* * *

[PlayLog Plugin Documentation](https://tuxreborn.netlify.app/#slim)

* * *


## 3). Connect a Squeezelite Client

LyrionMediaServer needs at least one client connected to actually play music and generate logs. Squeezelite is a lightweight software player that runs on almost any platform.

**For Linux/Termux:**

If you have a spare Android phone, or tablet, you can use Termux (a Linux terminal emulator) and run Squeezelite directly on it.

Once Termux is installed, open it and run:

```bash
pkg update
pkg install squeezelite
```

Start the player:

```bash
squeezelite -N my_phone -s 10.236.232.138
```

- The `-N my_phone` flag sets the player name (this will appear in the LyrionMediaServer web interface)
- The `-s 10.236.232.138` flag points to your LyrionMediaServer's IP address
- Replace the IP with your actual server address from the docker-compose configuration

**For Desktop Clients:**

If you prefer a graphical interface, you can download one of these clients:


- [Squeezelite-X](https://sourceforge.net/projects/lmsclients/files/squeezelitex/) (Windows): Full-featured player with GUI

- [SqueezePad](https://apps.apple.com/us/app/squeezepad/id380003002) (iPad): Touch-optimized controller and player

- [MacOS](https://lyrion.org/getting-started/mac-install/) (MacOS): If you [downloaded](https://lyrion.org/downloads/) Lyrion, once installed it will insert a menu into your menu bar right-hand side

- [Melodeon](https://flathub.org/en/apps/io.github.cdrummond.melodeon) (Flatpak): Qt5/6 wrapper around MaterialSkin rendered in QWebEngine

- [Squeezer](https://f-droid.org/packages/uk.org.ngo.squeezer/) (Android): I use it to control playback from my Android Wear device

- [Lyrion](https://f-droid.org/en/packages/com.craigd.lmsmaterial.app/) (Android): Beautiful execution of a WebView wrapper for accessing a Lyrion Music Server instance using MaterialSkin

- [Squeezelite](https://f-droid.org/en/packages/org.lyrion.squeezelite/) (Android): If you dont want to use Termux and would like a GUI



All clients will automatically discover your LyrionMediaServer if they're on the same network. Note that LyrionMediaServer uses multicast UDP for discovery, so if your clients are on a different network segment, you'll need to manually specify the server IP address.


* * *

## 4). Add Music and Test Playback

Before we can generate logs, we need music in the library:

### Step 1: Add Music Files

- Place some MP3s files in your `${MUSIC_STORAGE}` directory

- Dont have any MP3s? You can always find some new music at [OCRemix](https://ocremix.org/)

- Once you have your music in place

- In the LyrionMediaServer web interface, go to **Settings** → **Basic Settings**

- Under **Music Folder**, click **Scan** to index your files


### Step 2: Start Playing

- On your Squeezelite client device, you should see "my_phone" appear in the LyrionMediaServer web interface

- Select a song from your library

- Press play


### Step 3: Verify Logs Are Generated

Watch the Docker logs to confirm PlayLog is working:

```bash
docker logs -f LyrionMusicServer
```

You should see log entries like:

```
[XX-XX-XX XX:XX:XX.XXXX] Slim::Plugin::PlayLog::Plugin::logTrack (XXX) currently playing "Track Title	file:///.../music.mp3	Artist Name	Album Name"
```

This log format is what we'll parse in our Alloy configuration. The fields are tab-separated (`\t`) in the order: title, file path, artist, album.

### Didnt work?

- Help is here!

If you don't see these logs, verify:

- PlayLog is set to log "All tracks"

- Debug logging is enabled for `plugin.PlayLog`

- The LyrionMediaServer container was restarted after changing logging settings


* * *

# Part 8: Airsonic Advanced Setup

While LyrionMediaServer gives us basic music playback logs, it's mainly intended for around the house streaming.

Airsonic Advanced provides a more feature-rich music streaming web-server.

This section demonstrates a different logging pattern: instead of parsing unstructured text logs like we do with LyrionMediaServer, we'll extract metadata from Airsonic's file paths and cache operations.

(You can use your current working folder, `5-Lyrion-Airsonic-Grafana-Alerts`)


* * *

## What Is Airsonic Advanced?

Airsonic Advanced is a fork of the Airsonic music server, which itself is a fork of Subsonic. It's a self-hosted music streaming server with a web interface, mobile apps, and support for transcoding, playlists, and user management.

For our logging stack, Airsonic is interesting because:

- It logs every song access through its cache system

- We can parse artist and album information from standardized directory structures

* * *

## A Note About Music Organization

This configuration assumes your music follows a specific directory structure:

```
/music_folder/Artist/[album-type]/(year) - album_name/track_number - track_title.mp3
```

For example:
```
/music/Pink Floyd/[album]/(1973) - The Dark Side of the Moon/01 - Speak to Me.flac
/music/Led Zeppelin/[compilation]/(1990) - Remasters/05 - Whole Lotta Love.mp3
```

If your music isn't organized this way, I highly recommend using [Beets](https://beets.io/), a command-line tool that automatically organizes and tags your music library. The Docker image from LinuxServer.io makes this easy:

```bash
docker run -v /your/music:/music ghcr.io/linuxserver/beets
```

Configure Beets with this path format in `~/.config/beets/config.yaml`:

```yaml
paths:
    default: %asciify{$albumartist}/[$albumtype]/($original_year) - $album%aunique{}/$track - $title
    singleton: Non-Album/$artist - $title
    comp: Compilations/%asciify{$albumartist}/($original_year) - $album%aunique{}/$track - $title
    albumtype_soundtrack: Soundtracks/$album/$track $title
```

This folder structure is the best way to store your complete music archive. 

* * *

[Beets Documentation](https://beets.readthedocs.io/)


* * *

## 1). Configure Airsonic in Docker Compose

Add the Airsonic Advanced service to your `docker-compose.yml`:

```yaml
services:
  airsonic-advanced:
    image: airsonicadvanced/airsonic-advanced:latest
    container_name: airsonic-advanced
    environment:
      - TZ=America/Denver
      - CONTEXT_PATH=/
      - JAVA_OPTS=-Xms256m -Xmx512m
    env_file:
      - .env
    ports:
      - "4040:4040"     # WebUI
      - "4041:4041"     # WebUI-HTTPS
      - "1900:1900/udp" # Upnp
    volumes:
      - './appdata/airsonic-advanced:/var/airsonic:rw'
      - '${MUSIC_STORAGE}:/var/music/:ro'
      - '${MUSIC_STORAGE}/_podcasts:/var/podcasts:rw'
      - '${MUSIC_STORAGE}/_playlists:/var/playlists:rw'
    labels:
      - "alloy.job=airsonic"
      - "traefik.enable=true"
      - "traefik.http.services.airsonic.loadbalancer.server.port=4040"
      - "traefik.http.routers.airsonic.rule=Host(`airsonic.${DOMAIN}`) || Host(`music.${SUBDOMAIN}`)"
      - "traefik.http.routers.airsonic.entrypoints=websecure"
      - "traefik.http.routers.airsonic.tls=true"
      - "traefik.http.routers.airsonic.tls.certresolver=cloudflare"
      - "traefik.http.routers.airsonic.tls.domains[0].sans=*.${DOMAIN}"
      - "traefik.http.routers.airsonic.tls.domains[1].sans=*.${SUBDOMAIN}"
    networks:
      br1.232:
        ipv4_address: 10.236.232.156
```


Configuration details:


- Port 4040 is the main web interface

- Port 4041 is used for HTTPS if configured

- Port 1900 (UDP) is for UPnP/DLNA discovery

- The Docker label `alloy.job=airsonic` is important - we'll use this to filter logs in Alloy

- Configuration persists in `./appdata/airsonic-advanced`

- Music is mounted read-only; podcasts and playlists are read-write


Access the web interface at `http://10.236.232.156:4040`. The default credentials are:

- Username: `admin`

- Password: `admin`


Change these immediately after logging in for the first time.


* * *

### Best Practice: Use Docker Labels for Alloy Discovery

Docker lets you apply **labels to containers**, and Alloy can **use those labels to target the correct container log**.

In our example, in `docker-compose.yml` above:

```yaml
services:
  airsonic:
    image: ...
    labels:
      - "alloy.job=airsonic"
```

This adds a Docker label `alloy.job` with value `airsonic` to the container.



* * *

## 2). Configure Alloy to Discover Airsonic Container

Now we move to the Alloy side to configure log collection. Unlike our earlier general Docker discovery configuration, **we want to create a dedicated pipeline just for Airsonic logs**.

In your `config.alloy` file, we'll use a two-step approach: first discover all Docker containers, then filter to only the Airsonic container using a relabel rule.

### Step 1: Discover Airsonic Using Relabeling

This is our configuration for `config.alloy`:

```ini
// Discover and filter for Airsonic container
discovery.relabel "airsonic_container" {
    targets = discovery.docker.containers.targets

    // Only keep the airsonic-advanced container
    rule {
        source_labels = ["__meta_docker_container_name"]
        regex         = "/airsonic-advanced"
        action        = "keep"
    }

    // Remove the leading slash from container name
    rule {
        source_labels = ["__meta_docker_container_name"]
        regex         = "/(.*)"
        target_label  = "container"
    }

    // Add stream label (stdout/stderr)
    rule {
        source_labels = ["__meta_docker_container_log_stream"]
        target_label  = "stream"
    }
}
```

This relabeling configuration filters the discovered Docker containers to only include `airsonic-advanced`. The `action = "keep"` means any container that doesn't match the regex is dropped from this pipeline.

The second and third rules clean up the container name (removing the leading `/` that Docker adds) and add a stream label to distinguish stdout from stderr logs.


* * *

### Step 1 Alternative: Using Docker Labels Instead of Names

The configuration above filters by container name. If you prefer to use Docker labels (which a way better idea. It's is more flexible), you can filter by the `alloy.job=airsonic` label we added in the `docker-compose.yml` file.

Replace the first rule above with:

```ini
rule {
    source_labels = ["__meta_docker_container_label_alloy_job"]
    regex         = "airsonic"
    action        = "keep"
}
```

Docker labels are converted to Alloy metadata with the pattern: `__meta_docker_container_label_<label_name>`. Since our label is `alloy.job`, the dots are converted to underscores, giving us `__meta_docker_container_label_alloy_job`.

This approach has advantages:

- You can apply the same label to multiple containers

- You can easily enable/disable monitoring by adding/removing the label

- It's more explicit about which containers are being monitored



* * *

## 4). Configure Alloy to Read Airsonic Logs

With our filtered container targets ready, we can now configure the log source:

```ini
// Read logs from Airsonic container
loki.source.docker "airsonic_logs" {
    host       = "unix:///var/run/docker.sock"
    targets    = discovery.relabel.airsonic_container.output
    forward_to = [loki.process.airsonic_enrich.receiver]
}
```

This `loki.source.docker` component reads logs from the Docker socket, but only for containers that passed through our relabel filter. Notice we're not forwarding directly to Loki - instead, logs go to `loki.process.airsonic_enrich` for enrichment.

This is different from our general Docker log collection because we want to extract additional metadata from Airsonic's logs before storing them.


* * *

## 5). Parse Airsonic Logs and Add Labels

This is where the magic happens. Airsonic's cache logs contain file paths, and we can parse the artist name directly from those paths using regex. This creates searchable labels in Loki without storing duplicate data.

Add this processing pipeline to `config.alloy`:

```ini
//================================================================
// AIRSONIC MUSIC LOGS
// Take logs from Airsonic-Advanced into labels
//================================================================

// Filter Docker discovery for airsonic container (by name for now)
discovery.relabel "airsonic_container" {
    targets = discovery.docker.containers.targets

    // Only keep a containers with label: "alloy.job=airsonic"
    rule {
        source_labels = ["__meta_docker_container_label_alloy_job"]
        regex         = "airsonic"
        action        = "keep"
    }

    rule {
        source_labels = ["__meta_docker_container_log_stream"]
        target_label  = "stream"
    }
}

// Scrape ONLY airsonic logs from Docker
loki.source.docker "airsonic_logs" {
    host       = "unix:///var/run/docker.sock"
    targets    = discovery.relabel.airsonic_container.output
    forward_to = [loki.process.airsonic_enrich.receiver]
}

// Parse and enrich airsonic logs with IP, username, and artist info
loki.process "airsonic_enrich" {
    forward_to = [loki.write.local.receiver]

        // Add static job label FIRST (always applied)
        stage.static_labels {
            values = {
                job = "airsonic",
            }
        }

        // Extract IP from StreamController logs
        stage.match {
            selector = "{job=\"airsonic\"} |~ \"StreamController.*listening to\""

            stage.regex {
                expression = "(?P<ip>\\d+\\.\\d+\\.\\d+\\.\\d+): (?P<username>\\w+) listening to"
            }

            stage.labels {
                values = {
                    asonic_ip = "ip",
                    asonic_user  = "username",
                    log_type  = "stream",
                }
            }
        }

        // Extract artist from CacheConfiguration logs
        stage.match {
            selector = "{job=\"airsonic\"} |~ \"Cache Key:.*\\\\[(?:album|compilation|remix|single|ep)\\\\]\""

            stage.regex {
                expression = "Cache Key: (?P<artist>[^/]+)/\\[(?:album|compilation|remix|single|ep)\\]/"
            }

            stage.labels {
                values = {
                    asonic_music   = "artist",
                    log_type = "cache",
                }
            }
        }
}
```

Let's break down what each stage does:


* * *

### Stage 1: Static Labels
The `stage.static_labels` block adds `job="airsonic"` to every log line that enters this pipeline. This happens first, before any matching or parsing.


* * *

### Stage 2: Stream Log Parsing
The first `stage.match` block looks for logs containing `StreamController` and `listening to`. These are generated when a user starts playing a track. An example log looks like:

```
192.168.1.100: johndoe listening to /var/music/Pink Floyd/[album]/(1973) - Dark Side/01 - Speak to Me.flac
```

The `stage.regex` extracts:
- `ip` - The client's IP address (192.168.1.100)
- `username` - The Airsonic username (johndoe)

The `stage.labels` block converts these into Loki labels:
- `asonic_ip="192.168.1.100"`
- `asonic_user="johndoe"`
- `log_type="stream"`


* * *

### Stage 3: Cache Log Parsing
The second `stage.match` block processes cache access logs. These are generated when Airsonic reads file metadata. 

An example log:

```
Cache Key: Pink Floyd/[album]/(1973) - Dark Side of the Moon/01 - Speak to Me.flac
```

The regex extracts the artist name (`Pink Floyd`) from the file path. The `[^/]+` pattern means "capture everything up to the first forward slash", which corresponds to our artist folder.

The regex also validates the album type is one of: album, compilation, remix, single, or ep. This prevents false matches on other file paths.

The extracted data becomes:
- `asonic_music="Pink Floyd"`
- `log_type="cache"`

Logs that don't match either stage selector still get the `job="airsonic"` label but skip the extraction stages. This includes error logs, startup messages, and other operational logs.


* * *

## 6). Understanding the Label Hierarchy

After processing, your logs will have different labels depending on their type. Here's the complete label hierarchy:

**All Airsonic Logs:**
- `job="airsonic"` - Always present
- `container="airsonic-advanced"` - From discovery

**Stream Logs (user playback):**
- All labels from "All Airsonic Logs"
- `asonic_ip` - Client IP address
- `asonic_user` - Username
- `asonic_music` - Artist name

This labeling strategy lets you write precise queries in Grafana:
- `{job="airsonic"}` - All Airsonic logs
- `{job="airsonic", log_type="stream"}` - Only playback events
- `{job="airsonic", asonic_music="Pink Floyd"}` - Only Pink Floyd songs accessed
- `{job="airsonic", asonic_user="admin"}` - Only admin's activity


* * *

## 7). Verify Airsonic Log Collection

After adding this configuration to Alloy and restarting the container, verify it's working:

### Step 1: Check Alloy UI

Navigate to `http://your-alloy-host:12345/component/loki.process.airsonic_enrich`

You should see:

- Metrics showing logs processed

- The pipeline stages listed

- Any errors if the regex isn't matching


### Step 2: Play a Song in Airsonic

Go to your Airsonic web interface and play a song.


### Step 3: Query in Grafana

Open Grafana and go to Explore. Select your Loki datasource and run:

```
{job="airsonic"} | asonic_music != ""
```


You should see logs with the `asonic_music` label populated with artist names. If the label is empty or missing, check:

- Your music folder structure matches the expected format

- The regex in the `stage.regex` block matches your actual log format

- The cache logs are actually being generated (they may take a moment after playback starts)


* * *

# Part 9: Grafana Alerting System

Now that we have music streaming logs flowing into Loki with rich labels, we can configure Grafana's alerting system to notify us when specific songs or artists are played. This demonstrates the complete monitoring pipeline: logs → parsing → storage → alerting → notification.

Grafana's alerting system consists of three components that work together:
1. **Alert Rules** - Define what conditions trigger an alert
2. **Contact Points** - Define where to send notifications
3. **Notification Policies** - Define routing and timing behavior

We'll configure all three to send Telegram notifications when certain music is played.

(You can use your current working folder, `5-Lyrion-Airsonic-Grafana-Alerts`)

* * *

## How Grafana Alerting Works

Before diving into configuration, it helps to understand the alert flow:


### Step 1: Evaluation

Grafana periodically runs LogQL queries defined in alert rules. These queries check your Loki data for specific conditions.


### Step 2: State Change

When a query result crosses a threshold, the alert state changes from "Normal" to "Alerting". This state change is what triggers the next steps.


### Step 3: Notification Policy Matching

The alert is evaluated against notification policies. These policies determine which contact point receives the alert and control timing behaviors like grouping and repeat intervals.


### Step 4: Contact Point Execution

The selected contact point sends the notification to its configured destination (Telegram, email, Slack, etc.).


### Step 5: Repeat and Resolution

If the alert condition persists, notifications repeat according to the policy. When the condition clears, a resolution notification can optionally be sent.


* * *

## 1). Configure Telegram Bot for Notifications

Before we can send alerts to Telegram, we need to create a bot and get its credentials. This is a one-time setup process.

### Step 1: Create a Telegram Bot

- Open Telegram and search for `@BotFather`

- Send the command `/newbot`

- Follow the prompts to choose a name and username for your bot

- BotFather will respond with a token like `112233445:AAQQqTtvv11gGHJXxfFtESEOsaAcKsSBlaDWin`

- Save this token - you'll need it for the Grafana configuration


### Step 2: Get Your Chat ID

- Search for `@userinfobot` in Telegram

- Send it any message

- It will reply with your user ID (a number like `123456789`)

- This is your chat ID for personal messages


### Step 3: If you want to send alerts to a group

- Create a group and add your bot to it

- Add `@userinfobot` to the group temporarily

- The bot will show the group's chat ID (it will be negative, like `-987654321`)

- Remove `@userinfobot` after getting the ID


### Step 4: Add Credentials to .env File

Add these lines to your `.env` file:

```bash
MYTGRAM_BOTTOKEN=112233445:AAQQqTtvv11gGHJXxfFtESEOsaAcKsSBlaDWin
MYTGRAM_CHATID=123456789
```

Replace the values with your actual bot token and chat ID. These environment variables keep your credentials out of the configuration files.


* * *

## 2). Create Telegram Contact Point

Contact points define where Grafana sends notifications. We'll create one for Telegram using the provisioning system so it's automatically configured when Grafana starts.

We will be using the file `./grafana/provisioning/alerting/ContactPoint-Telegram.yaml`:

```yaml
apiVersion: 1
contactPoints:
  - orgId: 1
    name: MusicAlert_bot
    receivers:
      - uid: telegram_music_alerts
        type: telegram
        settings:
          bottoken: ${MYTGRAM_BOTTOKEN}
          chatid: >
            ${MYTGRAM_CHATID}
          disable_notification: false
          disable_web_page_preview: false
          protect_content: false
        disableResolveMessage: true
```

Let's break down this configuration:

### Contact Point Identification

- `name: MusicAlert_bot` - This is how you reference this contact point in notification policies

- `uid: telegram_music_alerts` - A unique identifier for this specific receiver


### Telegram Settings

- `bottoken` - References your bot token from the .env file

- `chatid` - Your personal or group chat ID (see the note below about the `>` syntax)

- `disable_notification: false` - Messages will trigger sound/vibration on your phone

- `disable_web_page_preview: false` - Telegram will show previews for any URLs in messages

- `protect_content: false` - Allows forwarding and saving messages


### Alert Behavior

- `disableResolveMessage: true` - When an alert clears, Grafana won't send a "resolved" notification. This prevents notification spam when music stops playing.


* * *

**Important: The ChatID YAML Syntax**

You'll notice the `chatid` uses special YAML syntax:

```yaml
chatid: >
  ${MYTGRAM_CHATID}
```

The `>` symbol is a YAML folded scalar. This is necessary because of a bug in Grafana's YAML parser (issue #69950). The chat ID is a number, but Telegram's API requires it as a string. Without the folded scalar syntax, Grafana interprets the environment variable as a number and the API call fails.

The indentation matters - the `${MYTGRAM_CHATID}` line must be indented relative to `chatid:`. This forces YAML to treat the entire value as a string type, even though it contains only digits.

This is not the only solution, but it's the cleanest way to handle numeric values that need to be strings without hardcoding quotes (which would prevent environment variable expansion).

* * *

[Grafana Telegram Configuration Documentation](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/configure-telegram/)

* * *


## 3). Create Notification Policy

Notification policies control the routing and timing of alerts. They determine which contact point receives each alert and how often notifications repeat.

We will be using the file `./grafana/provisioning/alerting/Notification-Policy.yaml`:

```yaml
apiVersion: 1
policies:
  - orgId: 1
    receiver: MusicAlert_bot
    group_by:
      - grafana_folder
      - alertname
    group_wait: 0s
    group_interval: 5m
    repeat_interval: 10m
```

### Routing Configuration

- `receiver: MusicAlert_bot` - All alerts matching this policy go to our Telegram contact point

- This is the root policy, so it applies to all alerts by default


### Grouping Configuration

- `group_by: [grafana_folder, alertname]` - Alerts are grouped by their folder location and rule name

- This means if both the Airsonic and Lyrion alerts fire simultaneously, they'll be sent as separate notifications

- Without grouping, you'd get one notification per label combination, which could be dozens of messages


### Timing Configuration

- `group_wait: 0s` - Send notifications immediately, don't wait to collect more alerts into the group

- `group_interval: 5m` - If more alerts join this group, wait 5 minutes before sending an update

- `repeat_interval: 10m` - If the alert condition persists, resend the notification every 10 minutes



This timing configuration is tuned for music alerts where:

- You want immediate notification when someone starts playing monitored songs

- You don't want spam if they listen to multiple songs in a row (hence the 5-minute grouping)

- You want periodic reminders if they're binge-listening (every 10 minutes)



* * *

### Extending This Policy

You can add nested policies for more complex routing. For example, to send critical alerts to Telegram with sound and warning alerts via email:

```yaml
policies:
  - orgId: 1
    receiver: MusicAlert_bot
    routes:
      - receiver: MusicAlert_bot
        matchers:
          - severity = critical
        group_wait: 0s
      - receiver: email_team
        matchers:
          - severity = warning
        group_wait: 5m
```

You can also add mute timings to silence notifications during specific hours:

```yaml
mute_time_intervals:
  - name: sleep_hours
    time_intervals:
      - times:
        - start_time: '23:00'
          end_time: '08:00'
```

Then reference it in your policy:

```yaml
policies:
  - orgId: 1
    receiver: MusicAlert_bot
    mute_time_intervals:
      - sleep_hours
```

* * *

[Grafana Notification Policy Documentation](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/create-notification-policy/)

* * *


## 4). Create Alert Rule for Lyrion Music

Alert rules define the actual conditions that trigger notifications. We'll create two rules: one for LyrionMediaServer and one for Airsonic. These demonstrate different approaches to log parsing.

The LyrionMediaServer alert uses regex to parse unstructured text logs at query time. We will be using the file `./grafana/provisioning/alerting/LyrionAlert.json`:

> Sorry I didnt include the JSON for the alerting, it was too large. Please find it in the repo link.

* * *

### Understanding the LogQL Query Above

```sql
sum by (title, artist) (
  rate({container=~"(?i)(lyrionmusicserver|lms)"}
    |= "currently playing"
    |~ `(?i)(nickelback|creed|insane clown posse|limp bizkit|crazy potato)`
    | regexp `currently playing "(?P<title>[^\t]+)\t(?P<url>[^\t]+)\t(?P<artist>[^\t]+)\t`
  [3s])
)
```

Let's break this down line by line:

* * *

#### Line 1: Label Filter

- `{container=~"(?i)(lyrionmusicserver|lms)"}` - Select logs from containers named "lyrionmusicserver" or "lms"

- The `(?i)` makes the match case-insensitive

- The `=~` operator means "matches this regex"


#### Line 2: Line Filter

- `|= "currently playing"` - Only logs containing this exact phrase

- This is a fast filter that runs before regex parsing

- Line filters are much faster than regex, so always use them when possible


#### Line 3: Content Filter

- `|~ (regex pattern)` - Only logs matching this regex pattern

- Looks for song titles or artists containing our monitored bands

- The list includes: Nickelback, Creed, Insane Clown Posse, Limp Bizkit, Crazy Potato


#### Line 4: Parse and Extract

- `| regexp` - Parse the log line and extract named groups

- `(?P<title>[^\t]+)` - Capture the song title (everything up to the first tab)

- `(?P<artist>[^\t]+)` - Capture the artist name (after the second tab)

- These become labels we can use in aggregations


#### Line 5: Rate Calculation

- `[3s]` - Calculate the rate over a 3-second window

- This converts log line counts into events per second


* * *

## 5). Create Alert Rule for Airsonic Music

The Airsonic alert uses pre-parsed labels from our Alloy configuration, making the query much simpler and more efficient.

We will be using the file `./grafana/provisioning/alerting/AirsonicAlert.json`:

> Sorry I didnt include the JSON for the alerting, it was too large. Please find it in the repo link.

* * *

### Understanding the LogQL Query

This query is much simpler than the Lyrion one because:

```sql
sum by (asonic_music) (
  rate({job="airsonic"}
    | asonic_music =~ `(?i)(nickelback|creed|fred durst|Rick Astley|Limp Bizkit)`
  [3m])
)
```

#### Line 1: Label Filter

- `{job="airsonic"}` - Select only Airsonic logs

- This is a label we added in our Alloy `stage.static_labels` block


#### Line 2: Label Matcher

- `| asonic_music =~ (regex)` - Filter on the pre-parsed artist label

- This label was extracted by our Alloy `stage.regex` from the cache file paths

- No regex parsing needed at query time - the work was already done by Alloy


#### Line 3: Rate and Aggregation

- `[3m]` - Calculate rate over a 3-minute window (longer than Lyrion because Airsonic logs are less frequent)

- `sum by (asonic_music)` - Group by artist name



#### Why This Is More Efficient

**The Lyrion query must**:

1. Search log content for keywords

2. Parse each matching log with regex

3. Extract title and artist at query time

4. Then aggregate the results



**The Airsonic query**:

1. Filter by job label (indexed, very fast)

2. Filter by artist label (also indexed)

3. Aggregate

By doing the parsing in Alloy, we've moved the expensive work from query time (when you're viewing dashboards) to ingestion time (when logs arrive). This makes dashboards faster and reduces load on Loki.

The tradeoff is that you need to know what you want to extract before logs arrive. You can't retroactively add labels to old logs. The Lyrion approach is more flexible - you can change the regex in your query anytime - but it's slower.


* * *

## 6). Test the Alert System

Now for the fun part - testing if everything works:


**Step 1: Verify Contact Point**

- In Grafana, go to **Alerting** → **Contact points**

- Find "MusicAlert_bot" in the list

- Click **Test** to send a test message to your Telegram

- You should receive a test notification within a few seconds



If the test fails:

- Check your bot token is correct in the `.env` file

- Verify you've started a conversation with your bot in Telegram (send it any message first)

- For group chats, ensure the bot was added before you got the chat ID



**Step 2: Play a Monitored Song**

- Open either LyrionMediaServer or Airsonic

- Play a song by one of the monitored artists (Nickelback, Creed, etc.)

- Wait up to 30 seconds for the alert to evaluate

- Check your Telegram for a notification



The notification should include:

- The alert title

- A summary showing which artist/song triggered it

- A timestamp

- Links back to Grafana



**Step 3: Verify Alert State in Grafana**

- Go to **Alerting** → **Alert rules**

- The triggered alert should show state "Alerting" with a red background

- Click on the alert to see its evaluation history and labels


If the alert doesn't fire:

- Check the query returns data in **Explore** (use the same LogQL query from the alert)

- Verify your logs are being collected (check `{job="airsonic"}` or `{container=~"lyrion.*"}`)

- Look at Grafana's logs for evaluation errors: `docker logs grafana`


* * *

## 7). Customizing Alert Behavior

Now that the basic system works, here are some ways to customize it:


**Add More Artists:**

Simply edit the regex pattern in the JSON files. For example, to also monitor for Taylor Swift:

```
|~ `(?i)(nickelback|creed|taylor swift|fred durst)`
```


**Alert on Specific Users:**

Modify the Airsonic query to include the user label:

```sql
sum by (asonic_music, asonic_user) (
  rate({job="airsonic", asonic_user="johndoe"}
    | asonic_music =~ `(?i)(nickelback|creed)`
  [3m])
)
```


**Change Notification Frequency:**

Edit `Notification-Policy.yaml`:

- Reduce `repeat_interval` to 5m for more frequent reminders

- Increase `group_interval` to 10m to batch more alerts together



**Add Severity Levels:**

Create separate alerts with different severity labels, then route them to different contact points:

```yaml
routes:
  - receiver: telegram_urgent
    matchers:
      - severity = critical
  - receiver: email_team
    matchers:
      - severity = warning
```

**Mute During Sleep Hours:**
Add mute timings to the notification policy:

```yaml
mute_time_intervals:
  - name: night_hours
    time_intervals:
      - times:
        - start_time: '22:00'
          end_time: '07:00'
        weekdays: ['saturday', 'sunday']
```


* * *

# Final Monitoring and Alerting Flow

Let's trace a single log line through the entire system to see how all the pieces connect:


**Step 1: Music Plays**

A user plays "Photograph" by Nickelback in Airsonic.


**Step 2: Airsonic Logs**

Airsonic writes a cache access log to stdout:

```
Cache Key: Nickelback/[album]/(2005) - All The Right Reasons/01 - Photograph.flac
```


**Step 3: Docker Captures**

The Docker daemon captures this stdout log from the container.


**Step 4: Alloy Discovers**

The `discovery.docker` block finds the Airsonic container.


**Step 5: Alloy Filters**

The `discovery.relabel` block matches the container name and keeps it for processing.


**Step 6: Alloy Reads**

The `loki.source.docker` block reads the log line from Docker.


**Step 7: Alloy Parses**

The `loki.process` pipeline:

- Adds label: `job="airsonic"`

- Matches the cache pattern

- Extracts: `asonic_music="Nickelback"`

- Adds label: `log_type="cache"`


**Step 8: Alloy Sends**

The processed log with all labels is sent to Loki at port 3100.


**Step 9: Loki Stores**

Loki indexes the labels and compresses the log line for storage.


**Step 10: Grafana Queries**

Every 30 seconds, Grafana runs the alert query:

```sql
{job="airsonic"} | asonic_music =~ `(?i)(nickelback|...)`
```


**Step 11: Condition Triggers**

The query returns a rate > 0, so the condition evaluates to true.


**Step 12: Policy Routes**

The notification policy matches the alert and selects the "MusicAlert_bot" contact point.


**Step 13: Telegram Sends**

The contact point uses the Telegram API to send a message to your phone.


**Step 14: You React**

Your phone buzzes with: "Airsonic playback detected: Nickelback"


And that's the complete flow from music playback to mobile notification, demonstrating the power of modern observability stacks for both serious monitoring and fun use cases like this.

* * *

- [Grafana Alerting Overview](https://grafana.com/docs/grafana/latest/alerting/)

- [LogQL Query Language Documentation](https://grafana.com/docs/loki/latest/query/)

- [Telegram Bot API Documentation](https://core.telegram.org/bots/api)

* * *

