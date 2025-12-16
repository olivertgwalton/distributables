#!/usr/bin/env bash

# Jellyfin Media Server install helper for the Riven LXC.
#
# This file is intended to be sourced by proxmox/riven-install.sh via:
#   source /dev/stdin <<<"$(curl -fsSL https://raw.githubusercontent.com/rivenmedia/distributables/main/proxmox/media-jellyfin.sh)"
#
# It assumes the following are already available in the environment:
#   - msg_info/msg_ok/msg_error functions (from tteck install.func)
#   - CTTYPE, PCT_OSTYPE, STD (optional), etc.
#
# It MUST NOT call exit; instead it should return non-zero on error so the
# caller can decide whether to continue.

install_jellyfin_media_server() {
  local APT_STD="${STD:-}"
  local OS_FAMILY="${PCT_OSTYPE:-debian}"

  msg_info "Installing Jellyfin dependencies"
  if ! ${APT_STD} apt-get install -y curl sudo mc gpg; then
    msg_error "Failed to install Jellyfin dependencies; skipping Jellyfin installation"
    return 1
  fi
  msg_ok "Installed Jellyfin dependencies"

  msg_info "Setting up Jellyfin hardware acceleration packages"
  if ! ${APT_STD} apt-get -y install va-driver-all ocl-icd-libopencl1 intel-opencl-icd vainfo intel-gpu-tools; then
    msg_error "Failed to install Jellyfin GPU/VAAPI packages (continuing without hardware acceleration)"
  else
    if [[ "${CTTYPE:-1}" == "0" && -d /dev/dri ]]; then
      chgrp video /dev/dri || true
      chmod 755 /dev/dri || true
      chmod 660 /dev/dri/* 2>/dev/null || true
      ${APT_STD} adduser "$(id -u -n)" video || true
      ${APT_STD} adduser "$(id -u -n)" render || true
    fi
    msg_ok "Set up Jellyfin hardware acceleration packages"
  fi

  msg_info "Configuring Jellyfin repository"
  mkdir -p /etc/apt/keyrings || true
  if ! curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key \
    | gpg --dearmor --yes --output /etc/apt/keyrings/jellyfin.gpg; then
    msg_error "Failed to configure Jellyfin signing key; skipping Jellyfin installation"
    return 1
  fi

  if ! cat <<EOF >/etc/apt/sources.list.d/jellyfin.sources
Types: deb
URIs: https://repo.jellyfin.org/${OS_FAMILY}
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF
  then
    msg_error "Failed to configure Jellyfin apt source; skipping Jellyfin installation"
    return 1
  fi
  msg_ok "Configured Jellyfin repository"

  msg_info "Installing Jellyfin Media Server"
  if ! ${APT_STD} apt-get update; then
    msg_error "apt-get update failed before Jellyfin installation; skipping Jellyfin"
    return 1
  fi
  if ! ${APT_STD} apt-get install -y jellyfin; then
    msg_error "Failed to install Jellyfin package"
    return 1
  fi

  chown -R jellyfin:adm /etc/jellyfin 2>/dev/null || true
  sleep 10
  systemctl restart jellyfin 2>/dev/null || true

  # Adjust ssl-cert/render groups for Jellyfin (best-effort).
  if [[ "${CTTYPE:-1}" == "0" ]]; then
    sed -i -e 's/^ssl-cert:x:104:jellyfin$/render:x:104:root,jellyfin/' \
      -e 's/^render:x:108:root$/ssl-cert:x:108:jellyfin/' /etc/group 2>/dev/null || true
  else
    sed -i -e 's/^ssl-cert:x:104:jellyfin$/render:x:104:jellyfin/' \
      -e 's/^render:x:108:$/ssl-cert:x:108:/' /etc/group 2>/dev/null || true
  fi

  msg_ok "Installed Jellyfin Media Server"
}

