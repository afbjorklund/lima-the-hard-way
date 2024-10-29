#!/bin/sh
qemu=qemu-system-x86_64
accel=kvm
machine=q35
cpus=1
memory=1024
port=2222
uefi=/usr/share/OVMF/OVMF_CODE.fd
$qemu -accel $accel -M $machine -cpu host -smp $cpus -m $memory -hda disk.img -cdrom seed.img -net nic -net user,hostfwd=tcp::$port-:22 -bios $uefi
