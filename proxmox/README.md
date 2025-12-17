# Proxmox LXC Helper Script for Riven

This repository contains a Proxmox helper script that creates a Debian 12, unprivileged
LXC container running the Riven backend and frontend on bare metal (no Docker).

---

## Requirements

- Proxmox VE **8.1 or later** (including 9.x)
- Internet connectivity from the Proxmox host and the LXC template mirrors
- A storage pool that can host LXC containers

The helper will create an **unprivileged** container (CT_TYPE=1) with sensible defaults:

- OS: Debian 12
- CPU: 4 vCPU
- RAM: 8 GB
- Disk: 40 GB

You can override these values via the script's **Advanced Settings** dialog.

---

## Creating the Riven LXC

Run this from a **Proxmox VE host shell**:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/olivertgwalton/distributables/main/proxmox/riven.sh)"
```

The script will:

- Validate your Proxmox version (8.1+)
- Create a new **unprivileged** Debian 12 LXC
- Enable FUSE and mount `/dev/fuse` inside the container
- Install and configure PostgreSQL inside the LXC
- Install the Riven backend (Python/uv) and frontend (Node/pnpm) bare metal
- Create systemd services for both backend and frontend so they start on boot

After the script completes, you should be able to reach:

- Riven backend at: `http://<CT-IP>:8080`
- Riven frontend at: `http://<CT-IP>:3000`

`<CT-IP>` is the IP address assigned to the LXC (shown in the script output and in `pct list`).

---

## What the installer sets up

Inside the Riven LXC, the installer configures:

- **Directories**
  - `/riven` – Riven backend checkout & virtualenv
  - `/riven/data` – data directory (used by the frontend's SQLite DB by default)
  - `/mount` – FUSE mountpoint for the Riven virtual filesystem (VFS)
  - `/opt/riven-frontend` – Riven frontend app
  - `/etc/riven` – configuration directory

- **Database**
  - PostgreSQL with database `riven`
  - `postgres` user password set to `postgres` (local-only, inside the CT)

- **Environment files**
  - Backend: `/etc/riven/backend.env`
    - `RIVEN_API_KEY` – randomly generated hex key used by the backend
    - `RIVEN_DATABASE_HOST=postgresql+psycopg2://postgres:postgres@127.0.0.1/riven`
    - `RIVEN_FILESYSTEM_MOUNT_PATH=/mount`
    - `RIVEN_LIBRARY_PATH=/mnt/riven` (path the media servers will see)
    - `RIVEN_FILESYSTEM_CACHE_DIR=/dev/shm/riven-cache`
  - Frontend: `/etc/riven/frontend.env`
    - `DATABASE_URL=/riven/data/riven.db` (SQLite)
    - `BACKEND_URL=http://127.0.0.1:8080`
    - `BACKEND_API_KEY=$RIVEN_API_KEY` (same value as backend)
    - `AUTH_SECRET` – randomly generated, used by the frontend for auth
    - `ORIGIN=http://localhost:3000`

- **Systemd services** (inside the CT)
  - `riven-backend.service`
  - `riven-frontend.service`

Both services are enabled and will start automatically when the LXC boots.

---

## Checking status and logs

Assuming your Riven container ID is `106`.

### Enter the container

```bash
pct enter 106
```

### Check service status

```bash
systemctl status riven-backend
systemctl status riven-frontend
```

### View live logs

```bash
journalctl -u riven-backend -f
journalctl -u riven-frontend -f
```

You can also run these directly from the Proxmox host without entering the CT:

```bash
lxc-attach -n 106 -- journalctl -u riven-backend -f
lxc-attach -n 106 -- journalctl -u riven-frontend -f
```

---

## Customizing configuration

You can edit the environment files inside the Riven CT to customize settings:

- `/etc/riven/backend.env`
- `/etc/riven/frontend.env`

After making changes, restart the services:

```bash
systemctl restart riven-backend riven-frontend
```

For advanced configuration (content providers, scrapers, ranking, etc.),
refer to the upstream Riven documentation and `.env.example` file in the
Riven repository.
