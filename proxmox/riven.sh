#!/usr/bin/env bash

# Proxmox helper script to create a Riven LXC (Debian 12, unprivileged)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_FUNC_LOCAL="${SCRIPT_DIR}/build.func"
if [ -f "$BUILD_FUNC_LOCAL" ]; then
  source "$BUILD_FUNC_LOCAL"
else
  # Fallback to remote build.func when running directly via curl from GitHub
  source <(curl -s https://raw.githubusercontent.com/rivenmedia/distributables/main/proxmox/build.func)
fi

function header_info {
clear
cat <<'EOF'
.______       __  ____    ____  _______ .__   __. 
|   _  \     |  | \   \  /   / |   ____||  \ |  | 
|  |_)  |    |  |  \   \/   /  |  |__   |   \|  | 
|      /     |  |   \      /   |   __|  |  . `  | 
|  |\  \----.|  |    \    /    |  |____ |  |\   | 
| _| `._____||__|     \__/     |_______||__| \__| 

Riven LXC Helper
EOF
}

header_info
echo -e "Loading..."

APP="Riven"
var_disk="40"
var_cpu="4"
var_ram="8192"
var_os="debian"
var_version="12"

variables
color
catch_errors

function default_settings() {
	CT_TYPE="1"
	PW=""
	CT_ID=$NEXTID
	HN=$NSAPP
	DISK_SIZE="$var_disk"
	CORE_COUNT="$var_cpu"
	RAM_SIZE="$var_ram"
	BRG="vmbr0"
	NET="dhcp"
	GATE=""
	APT_CACHER=""
	APT_CACHER_IP=""
	DISABLEIP6="no"
	MTU=""
	SD=""
	NS=""
	MAC=""
	VLAN=""
	SSH="no"
	VERB="no"
	RIVEN_INSTALL_FRONTEND="yes"
	RIVEN_FRONTEND_ORIGIN=""
	echo_default
}

function update_script() {
  msg_error "No ${APP} update script is available yet."
  exit 1
}

start
build_container
description

RIVEN_CT_ID="${CTID:-}"
if [ -z "$RIVEN_CT_ID" ]; then
	RIVEN_CT_ID="<RIVEN_CT_ID>"
fi

RIVEN_CT_IP=""
if command -v pct >/dev/null 2>&1 && [ -n "${CTID:-}" ]; then
	RIVEN_CT_IP=$(pct exec "$CTID" ip a s dev eth0 | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
fi
if [ -z "$RIVEN_CT_IP" ]; then
	RIVEN_CT_IP="<RIVEN_CT_IP>"
fi

msg_ok "Completed Successfully!\n"

echo -e "Riven container ID:  ${BL}${RIVEN_CT_ID}${CL}"
echo -e "Riven container IP:  ${BL}${RIVEN_CT_IP}${CL}\n"

echo -e "${APP} backend (API) URL:"
echo -e "  ${BL}http://${RIVEN_CT_IP}:8080/scalar${CL}\n"

if [ "${RIVEN_INSTALL_FRONTEND:-yes}" != "no" ]; then
	echo -e "${APP} frontend (web UI) URL:"
	echo -e "  ${BL}http://${RIVEN_CT_IP}:3000${CL}\n"
else
	echo -e "${APP} frontend was ${RD}not installed${CL} in this container."
	echo -e "You can host it elsewhere and point it at the backend URL above.\n"
fi

echo -e "Backend settings file inside the container:"
echo -e "  ${BL}/riven/src/data/settings.json${CL}\n"

echo -e "To share your media into this Riven container and a media server container (Plex/Jellyfin/Emby):"
echo -e "  1) On the Proxmox host, choose or create a media folder (for example):"
echo -e "       ${BL}/mnt/media${CL}"
echo -e "  2) Still on the Proxmox host, add that folder to the Riven container (IDs/path filled in for you):"
echo -e "       ${BL}pct set ${RIVEN_CT_ID} -mp0 /mnt/media,mp=/mnt/riven${CL}"
echo -e "  3) Then add the same folder to your media server container (Plex/Jellyfin/Emby/etc):"
echo -e "       ${BL}pct set <MEDIA_CT_ID> -mp1 /mnt/media,mp=/mnt/riven${CL}\n"
echo -e "Make sure the host media folder is world-readable so the riven user can read the files:"
echo -e "       ${BL}chmod 755 /mnt/media${CL}\n"
