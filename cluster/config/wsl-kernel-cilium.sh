# WSL2 Linux kernel compilation for Cilium eBPF support
#
# Use this ONLY if:
# 1. You're running Cilium in WSL2 (development/testing, not typical)
# 2. The default WSL2 kernel doesn't have eBPF support enabled
# 3. You need to recompile the kernel with CONFIG_HAVE_EBPF_JIT=y
#
# For most homelabs running Cilium on bare metal or cloud VMs, skip this script.
#
# Recompiling the kernel takes 30–60 minutes. Reference:
# https://docs.cilium.io/en/stable/installation/kind-install/
#

sudo apt update && sudo apt install build-essential bc dwarves flex git bison libssl-dev libelf-dev

git clone https://github.com/microsoft/WSL2-Linux-Kernel.git

cd WSL2-Linux-Kernel

vim ./Microsoft/config-wsl

make -j$(nproc) KCONFIG_CONFIG=Microsoft/config-wsl

sudo make modules_install headers_install

cp arch/x86/boot/bzImage /mnt/c/some_folder_on_your_windows_disk

sudo rm WSL2-Linux-Kernel/ -r

awk '(NR>1) { print $2 }' /usr/lib/modules/$(uname -r)/modules.alias | sudo tee /etc/modules-load.d/cilium.conf

sudo nano /lib/systemd/system/systemd-modules-load.service

sudo systemctl daemon-reload

sudo systemctl restart systemd-modules-load

sudo lsmod