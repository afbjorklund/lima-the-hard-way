#!/bin/sh
qemu=qemu-system-aarch64
accel=hvf
machine=virt
cpus=1
memory=1024
port=2222
uefi=/opt/homebrew/share/qemu/edk2-aarch64-code.fd
$qemu -accel $accel -M $machine -cpu host -smp $cpus -m $memory -drive media=disk,index=0,if=virtio,file=disk.img -drive media=cdrom,index=2,if=virtio,file=seed.img -net nic,model=virtio -net user,hostfwd=tcp::$port-:22 -bios $uefi
