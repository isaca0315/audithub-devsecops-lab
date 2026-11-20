#!/bin/sh
# Instala Docker, Compose v2 y herramientas opcionales en Ubuntu 24.04 o Kali.
# Uso: sudo sh scripts/install-tools.sh [usuario]
set -eu

target_user=${1:-${SUDO_USER:-$(id -un)}}

. /etc/os-release
case "$ID" in
  ubuntu|kali) ;;
  *) echo "Solo Ubuntu o Kali (detectado: $ID)" >&2; exit 1 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git docker.io nmap ffuf gobuster gitleaks lynis netcat-openbsd
apt-get install -y trivy || echo "Aviso: trivy no está en los repositorios; instalarlo desde https://trivy.dev"

# Compose v2 como plugin de la CLI: permite 'docker compose'.
arch=$(uname -m)
case "$arch" in
  x86_64) compose_arch=x86_64 ;;
  aarch64|arm64) compose_arch=aarch64 ;;
  *) echo "Arquitectura no soportada: $arch" >&2; exit 1 ;;
esac
compose_version=v5.8.0
plugin_dir=/usr/local/lib/docker/cli-plugins
mkdir -p "$plugin_dir"
curl -fsSL "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-linux-${compose_arch}" \
  -o "$plugin_dir/docker-compose"
chmod +x "$plugin_dir/docker-compose"

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now docker || service docker start
else
  service docker start || true
fi

if [ "$target_user" != "root" ]; then
  usermod -aG docker "$target_user" || true
  echo "Agregado $target_user al grupo docker: cerrá sesión y volvé a entrar."
fi

if [ ! -d /opt/docker-bench-security ] && command -v git >/dev/null 2>&1; then
  git clone --depth 1 https://github.com/docker/docker-bench-security.git /opt/docker-bench-security || true
fi

echo "Instalación terminada. Verificá con: docker compose version"
