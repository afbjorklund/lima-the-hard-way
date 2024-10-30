#!/bin/sh
cpus=1
memory=1024
mac="52:54:00:70:2b:71"
vars="efi-variable-store"
vfkit --cpus $cpus --memory $memory --device virtio-blk,path=disk.raw --device virtio-blk,path=seed.img --device virtio-net,nat,mac=$mac --bootloader efi,variable-store=$vars,create
