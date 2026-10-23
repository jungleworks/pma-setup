# phpMyAdmin Setup

Runs phpMyAdmin in Docker on the same server as MySQL. Users log in with their own MySQL username and password, including accounts limited to `localhost`.

## What's in this repo

| File | Purpose |
|---|---|
| `docker-compose.yml` | phpMyAdmin container: host networking, port 444, connects to MySQL on `127.0.0.1` |
| `install.sh` | Optional helper: installs Docker + Docker Compose on Amazon Linux, then starts phpMyAdmin |

The only thing phpMyAdmin needs is **Docker with the Compose plugin**. `install.sh` exists purely to install those two on a fresh server. If Docker and Docker Compose are already installed, skip it and start phpMyAdmin directly.

## Requirements

- Linux server (x86_64 or ARM/Graviton)
- Docker and the Docker Compose plugin, or root access so `install.sh` can install them (Amazon Linux / `yum`-based distros)
- MySQL running on the same server, accepting TCP connections on `127.0.0.1:3306`

### MySQL prerequisites

phpMyAdmin connects to MySQL on `127.0.0.1`, so MySQL treats every login as coming from `localhost`. Any account allowed from `localhost` or `%` can log in. No MySQL configuration changes are needed, and `bind-address = 127.0.0.1` is fine.

## Installation

### Option A: Docker and Docker Compose already installed

```bash
git clone <repo-url> /opt/pma-setup
cd /opt/pma-setup
docker compose up -d
```

Make sure Docker starts on boot, so phpMyAdmin comes back after a reboot:

```bash
systemctl enable docker
```

### Option B: Fresh server (Amazon Linux)

```bash
yum install -y git
git clone <repo-url> /opt/pma-setup
cd /opt/pma-setup
./install.sh
```

The script:

1. Installs Docker and enables it on boot
2. Installs the latest Docker Compose plugin
3. Starts phpMyAdmin (`docker compose up -d`)
4. Prints the PHP version running inside the container

Either way, phpMyAdmin is then available at `http://<server-ip>:444`.

Clone to a fixed location like `/opt/pma-setup`. The container belongs to that folder, and updates are run from there.

## Updating

```bash
cd /opt/pma-setup
git pull
docker compose up -d
```

The compose file uses `pull_policy: always`, so `docker compose up -d` fetches the latest phpMyAdmin image and recreates the container if there's a newer one. Running `./install.sh` again also works and additionally updates Docker Compose.

Update promptly after PHP security releases, since phpMyAdmin is only as secure as the PHP it runs on.

## Checking versions

```bash
docker exec pma php -v
docker inspect pma --format '{{.Config.Image}}'
```

Compare the PHP version against the supported versions and latest security releases at https://www.php.net/supported-versions.php.

## Configuration

All settings are in `docker-compose.yml`:

| Setting | Default | Purpose |
|---|---|---|
| `APACHE_PORT` | `444` | Port phpMyAdmin listens on |
| `PMA_HOST` | `127.0.0.1` | MySQL server to connect to |

The container uses host networking (`network_mode: host`), so `APACHE_PORT` is the port directly on the server. No port mapping is involved.

After changing anything, run `docker compose up -d` in the repo folder.

## Troubleshooting

**`Access denied for user 'root'@'localhost'`**
Check how root authenticates:
```sql
SELECT user, host, plugin FROM mysql.user WHERE user = 'root';
```
If the plugin is `auth_socket` or `unix_socket`, root can only log in via the server's Unix socket, never through phpMyAdmin. Use a separate admin account instead. If it's a password plugin (`caching_sha2_password`, `mysql_native_password`), the password is wrong.

**`Access denied` for a normal user**
Check that the account allows `localhost` or `%`:
```sql
SELECT user, host FROM mysql.user WHERE user = 'alice';
```

**Can't connect to MySQL at all**
Check that MySQL is running and listening on port 3306:
```bash
ss -ltnp | grep 3306
```

**`address already in use` on startup**
Something else is using port 444. Check with `ss -ltnp | grep :444`, then stop it or change `APACHE_PORT` in `docker-compose.yml`.

**Running an old version after an update**
Make sure you ran `docker compose up -d` from the repo folder. To check where a running container was started from:
```bash
docker inspect pma --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}'
```

## Security notes

- phpMyAdmin serves **plain HTTP** on port 444, so passwords travel unencrypted. Put it behind a reverse proxy with HTTPS before using it over untrusted networks.
- With host networking, port 444 is open on all of the server's network interfaces. In the AWS security group, allow it **only** from the addresses that need it (office IP, VPN).
- Check that MySQL ports 3306 and 33060 aren't open to the internet in the security group.
- Use MySQL accounts with only the privileges each person needs. phpMyAdmin enforces whatever MySQL allows.
