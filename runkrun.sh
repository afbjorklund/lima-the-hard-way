#!/bin/sh
cpus=1
memory=1024
mac="52:54:00:70:2b:72"
vars="efi-variable-store"
krunkit --cpus $cpus --memory $memory --device virtio-blk,path=disk.raw,format=raw --device virtio-blk,path=seed.img,format=raw --device virtio-net,unixSocketPath=/tmp/network.sock,mac=$mac --bootloader efi,variable-store=$vars,create
