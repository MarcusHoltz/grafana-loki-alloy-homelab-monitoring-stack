# Part 0: Setup the Lab Enviornment

Be sure you have copied the required files from the github repo.

Before we can spin up docker, there are things we need to do:

- Run: `1_permissions_init_for_project.sh`

- Edit: `.env`

- Edit: `./traefik/traefik.yml`

- Review: `docker network`


* * *

## 1_permissions_init_for_project.sh script

For ease of use, just run the `1_permissions_init_for_project.sh` script that will set permissions for you.

There are two permissions that need set, as we'll be using files outside of the container - on the host.

- `acme.json` needs `600` in the `./traefik` directory

- `data` directory must be owned by UID `10001` in the `./loki` directory


* * *

## .env file

The .env file stores all of the variables we will use throughout. Please review and make changes (instructions for Telegram are included when we get there).

The sections include:

- `Docker Compose information` for `DOMAIN` and `Let's Encrypt`

- `Cloudflare API` for Let's Encrypt DNS-01 certificates

- Your `Grafana Cloud` information

- The location of your `Music` for generating logs

- Your `UID/GID` for that user's Music folder

- `Telegram` for Grafana alerts needs the `token` and `chatid`


* * *


## `traefik.yml` in the traefik directory

This file is our static traefik config. It should never need updating, except for this one thing.

- At the bottom of the file, under the "Certificate Resolvers", you will find `email:` and will have `"your_email_address@some_email_provider.com"`

- Change the `"your_email_address@some_email_provider.com"` to an email address you have access to (this is for LE renewals)


* * *

## Docker Network

So this write-up uses an external docker network. That network is a macvlan that allows each container to get their own address on the network connected to the parent interface (eth0), with the name of the bridged docker network being (br1.232).

`docker network create -d macvlan --subnet=10.236.232.0/24 --gateway=10.236.232.254 -o parent=eth0 br1.232`

Please adjust the settings for the network used throughout for your own use.


* * *

## Before Starting Part 1-9

* * *

### Working Folder Workflow

You will have to copy folders before starting each step.

You'll have:

- Base folder (`0-Setup-Lab-Environment`) that needs edited once.

- A working folder (`Some-Folder-Name-Here`) that gets deleted and recreated for each step.


* * *

### Initial Setup (Do This Once)

1. Complete everything in your `0-Setup-Lab-Environment` folder:
   - Run `1_permissions_init_for_project.sh`
   - Edit `.env` with your details
   - Update the email in `./traefik/traefik.yml`
   
2. Create the Docker network 
   - `docker network create -d macvlan --subnet=10.236.232.0/24 --gateway=10.236.232.254 -o parent=eth0 br1.232`


* * *

### For Each Part 1,2,3,7

1. Create a new working folder

2. Copy everything from `0-Setup-Lab-Environment` into it

3. Add the files for your current part

4. Run `1_permissions_init_for_project.sh` again

5. Run `docker-compose up`


* * *

### Moving to the Next Part

1. Delete your working folder completely

2. Repeat the process above with the new step's files

**Why?** This keeps your base configuration clean and gives you a fresh start for each step. You're always working with `0-Setup-Lab-Environment` + current step files, nothing more.

**Reminder**: Never edit `0-Setup-Lab-Environment` after initial setup. Always work in your temporary working folder.

