#!/bin/sh
accel=kvm
cpus=1
memory=1024
port=2222
qemu-system-x86_64 -accel $accel -smp $cpus -m $memory -hda disk.img -cdrom seed.img -net nic -net user,hostfwd=tcp::$port-:22 -bios /usr/share/qemu/OVMF.fd
