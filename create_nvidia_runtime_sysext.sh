#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION"
  echo "The script will build nvidia-container-toolkit on ubuntu 18 and package it into a syseext."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

# Default should be: v1.14.3
VERSION="$1"
SYSEXTNAME="nvidia"

# The github release uses different arch identifiers, we map them here
# and rely on bake.sh to map them back to what systemd expects
if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" = "arm64" ]; then
  ARCH="arm64"
fi

git clone -b ${VERSION} --depth 1 https://github.com/NVIDIA/libnvidia-container || true
git clone -b ${VERSION} --depth 1 https://github.com/NVIDIA/nvidia-container-toolkit || true

make -C libnvidia-container ubuntu18.04-${ARCH}
make -C nvidia-container-toolkit ubuntu18.04-${ARCH}

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"
for deb in libnvidia-container/dist/ubuntu18.04/${ARCH}/libnvidia-container{1_*,-tools_}*.deb; do
  dpkg-deb -x $deb "${SYSEXTNAME}"/
done
for deb in nvidia-container-toolkit/dist/ubuntu18.04/${ARCH}/nvidia-container-toolkit*.deb; do
  dpkg-deb -x $deb "${SYSEXTNAME}"/
done
rm -rf "${SYSEXTNAME}"/usr/share
mv "${SYSEXTNAME}"/usr/lib/*-linux-gnu "${SYSEXTNAME}"/usr/lib64
mkdir -p "${SYSEXTNAME}"/usr/local
ln -s /opt/nvidia "${SYSEXTNAME}"/usr/local/nvidia
ln -s /opt/bin/nvidia-smi "${SYSEXTNAME}"/usr/bin/nvidia-smi

mkdir -p "${SYSEXTNAME}"/usr/bin
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
