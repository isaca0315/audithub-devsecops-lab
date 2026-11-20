#!/bin/sh
# Instala Docker, Compose v2 y herramientas opcionales en Ubuntu 24.04 o Kali.
# Omite lo que ya está instalado: en Kali varias herramientas vienen en el sistema.
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

packages="ca-certificates curl git docker.io nmap ffuf gobuster gitleaks lynis netcat-openbsd"
missing=""
for pkg in $packages; do
  dpkg -s "$pkg" >/dev/null 2>&1 || missing="$missing $pkg"
done
if [ -n "$missing" ]; then
  apt-get install -y $missing
else
  echo "Paquetes ya instalados: se omite apt-get install."
fi

if ! dpkg -s trivy >/dev/null 2>&1; then
  apt-get install -y trivy || echo "Aviso: trivy no está en los repositorios; instalarlo desde https://trivy.dev"
fi

# Compose v2 como plugin de la CLI: permite 'docker compose'.
arch=$(uname -m)
case "$arch" in
  x86_64) compose_arch=x86_64 ;;
  aarch64|arm64) compose_arch=aarch64 ;;
  *) echo "Arquitectura no soportada: $arch" >&2; exit 1 ;;
esac
compose_version=v5.8.0
plugin_dir=/usr/local/lib/docker/cli-plugins
compose_bin="$plugin_dir/docker-compose"
if [ ! -x "$compose_bin" ] || ! "$compose_bin" version | grep -q "$compose_version"; then
  mkdir -p "$plugin_dir"
  curl -fsSL "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-linux-${compose_arch}" \
    -o "$compose_bin"
  chmod +x "$compose_bin"
fi
if ! docker compose version 2>/dev/null | grep -q "$compose_version"; then
  echo "Aviso: otro plugin tiene prioridad. Revisá ~/.docker/cli-plugins/docker-compose"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now docker || service docker start
else
  service docker start || true
fi

if [ "$target_user" != "root" ] && ! id -nG "$target_user" | grep -qw docker; then
  usermod -aG docker "$target_user"
  echo "Agregado $target_user al grupo docker: cerrá sesión y volvé a entrar."
fi

if [ ! -d /opt/docker-bench-security ] && command -v git >/dev/null 2>&1; then
  git clone --depth 1 https://github.com/docker/docker-bench-security.git /opt/docker-bench-security || true
fi

echo "Instalación terminada. Verificá con: docker compose version"
