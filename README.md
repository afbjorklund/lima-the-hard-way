# Lima, The Hard Way

Installing a Linux Machine (Lima), for running Containers and Kubernetes with.

Similar to `docker-machine` and `minikube` solutions, but Do It Yourself (DIY).

Normally you would just use `lima`.

And it would do everything for you!

## Introduction

The end goal is to create a virtual machine (VM), that is able to run containers.

Then we can use this container runtime (CR), for orchestrating k8s applications.

Pre-requisites:
- QEMU
- KVM

Note: For macOS hosts, use HVF instead of KVM. (macOS 10+ "Hypervisor.framework")

Note: For Windows hosts, use WHPX instead of KVM. (Windows "Hypervisor Platform")

Optional:
- wget
- sha256sum
- gpg
- genisoimage (or `mkisofs` from "cdrtools")

Note: You can use [wcurl](https://curl.se/wcurl/) instead of `wget`, see [curl vs wget](https://daniel.haxx.se/docs/curl-vs-wget.html).

Note: You can use [bsdsum](https://github.com/afbjorklund/bsdsum) `sha256sum` instead of coreutils.

## Limitations

There will be **no** native virtualization drivers used here, like VZ or WSL2.

There will be **no** rootless containers, only the basic rootful containers.

There will be **no** advanced containerd configuration or add-ons, only basic.

There will be **no** other container engines, only containerd and buildkitd.

## Contents

* Containers
  * cloud-init
  * containerd

* Kubernetes
  * kubeadm
  * kind

Note: It is recommended to allocate 4 CPU and 4 GiB RAM to your virtual machine.

You will need a minimum of 1/1 for Containers, and 2/2 for Kubernetes (kubeadm).

## Linux

Distributions:

* Ubuntu 24.04 "noble"

* Debian 12 "bookworm"

## Containers

cpus=1
memory=1G

### ubuntu

```
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/noble/current/SHA256SUMS{,.gpg}
```

<https://ubuntu.com/tutorials/how-to-verify-ubuntu>

```console
$ gpg --keyid-format long --verify SHA256SUMS.gpg SHA256SUMS
gpg: Signature made Thu Sep 12 20:25:00 2024 CEST
gpg:                using RSA key D2EB44626FDDC30B513D5BB71A5D6C4C7DB87C81
gpg: Good signature from "UEC Image Automatic Signing Key <cdimage@ubuntu.com>" [unknown]
```

```console
$ sha256sum --check --ignore-missing SHA256SUMS
noble-server-cloudimg-amd64.img: OK
```

ln -sf noble-server-cloudimg-amd64.img base.img

### debian

```shell
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
wget https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS
```

ln -sf debian-12-genericcloud-amd64.qcow2 base.img

Note: feel free to replace default username "ubuntu" with "debian" below.

### disk

`disk.img`

```shell
qemu-img create -F qcow2 -b base.img -f qcow2 disk.img
qemu-img resize disk.img 20g
```

If using VZ instead of QEMU, the images have to be converted:

```shell
# convert images to raw, when using Virtualization.framework
qemu-img convert base.img base.raw
cp -c base.raw disk.raw
truncate -s 20g disk.raw
```

### cloud-init

<https://cloudinit.readthedocs.io/en/latest/howto/run_cloud_init_locally.html>

`seed.img`

```yaml
#cloud-config
users:
  - name: ubuntu
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: false
    plain_text_passwd: password
chpasswd: { expire: false }
ssh_pwauth: true
```

```shell
genisoimage \
    -output seed.img \
    -volid cidata -rational-rock -joliet \
    user-data meta-data network-config
```

```console
$ isoinfo -d -i seed.img
CD-ROM is in ISO 9660 format
System id: LINUX
Volume id: cidata
...
$ isoinfo -f -i seed.img -R -J
/meta-data
/network-config
/user-data
```

### qemu-system

<https://www.qemu.org/docs/master/system/>

```console
$ file *.img
base.img: symbolic link to ubuntu/noble-server-cloudimg-amd64.img
disk.img: QEMU QCOW2 Image (v3), has backing file (path base.img), 21474836480 bytes
seed.img: ISO 9660 CD-ROM filesystem data 'cidata'
$ du -hs *.img
0	base.img
200K	disk.img
364K	seed.img
```

```shell
qemu-system-x86_64 -accel kvm -M q35 -cpu host -smp 1 -m 1024 \
                   -hda disk.img -cdrom seed.img \
                   -net nic -net user,hostfwd=tcp::2222-:22 \
                   -bios /usr/share/OVMF/OVMF_CODE.fd # <- efi
```

Note: it is possible to use "vfkit", instead of "qemu-system-*"<br />
See <https://github.com/crc-org/vfkit> for details (it uses VZ)

### ssh

The above setup (cloud-config.yaml) will use password login:

```console
$ ssh -p 2222 ubuntu@127.0.0.1
ubuntu@127.0.0.1's password: ^C

```

You can generate a key, and copy it to the authorized keys:

```shell
ssh-keygen -f keyfile -N "" # <-no passphrase
ssh-copy-id -i keyfile -p 2222 ubuntu@127.0.0.1

ssh -i keyfile ubuntu@127.0.0.1
```

Or you can use a different user-data, to set up with the .pub:

```yaml
#cloud-config
users:
  - name: ubuntu
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
     - "ssh-rsa AAAA... user@host"
```

This way there will not be any default password during setup.

### access

Copy a file from the host (local) to the guest (remote):

`scp -P 2222 localpath ubuntu@127.0.0.1:remotepath`

Tunnel a http port over a ssh process in the background:

`ssh -L 8080:127.0.0.1:8080 -p 2222 ubuntu@127.0.0.1 &`

With Lima, your filesystem mounts are shared automatically.

And the ports are also forwarded to localhost automatically.

If you only want this functionality, you can use `sshocker`:

<https://github.com/lima-vm/sshocker>

### containerd

<https://containerd.io/docs/getting-started/>

containerd
* runc
* cni-plugins
* nerdctl
* buildkit

#### containerd

```shell
wget https://github.com/containerd/containerd/releases/download/v1.7.22/containerd-1.7.22-linux-amd64.tar.gz
wget https://github.com/containerd/containerd/releases/download/v1.7.22/containerd-1.7.22-linux-amd64.tar.gz.sha256sum
```

```console
$ sha256sum -c containerd-1.7.22-linux-amd64.tar.gz.sha256sum
containerd-1.7.22-linux-amd64.tar.gz: OK
```

`sudo tar Cxzvf /usr/local containerd-1.7.22-linux-amd64.tar.gz`

```shell
wget https://raw.githubusercontent.com/containerd/containerd/v1.7.22/containerd.service
```

sudo install -D containerd.service /usr/local/lib/systemd/system/containerd.service

#### runc

```shell
wget https://github.com/opencontainers/runc/releases/download/v1.1.14/runc.amd64
wget https://github.com/opencontainers/runc/releases/download/v1.1.14/runc.sha256sum && grep runc.amd64 <runc.sha256sum >runc.amd64.sha256sum && rm runc.sha256sum
```

install -m 755 runc.amd64 /usr/local/sbin/runc

#### cni-plugins

```shell
wget https://github.com/containernetworking/plugins/releases/download/v1.5.1/cni-plugins-linux-amd64-v1.5.1.tgz
wget https://github.com/containernetworking/plugins/releases/download/v1.5.1/cni-plugins-linux-amd64-v1.5.1.tgz.sha256
```

`sudo tar Cxzvf /usr/local/lib/cni cni-plugins-linux-amd64-v1.5.1.tgz`

#### nerdctl

```shell
wget https://github.com/containerd/nerdctl/releases/download/v1.7.7/nerdctl-1.7.7-linux-amd64.tar.gz
wget https://github.com/containerd/nerdctl/releases/download/v1.7.7/SHA256SUMS -O - | grep nerdctl-1.7.7-linux-amd64.tar.gz >nerdctl-1.7.7-linux-amd64.tar.gz.sha256sum
```

`sudo tar Cxzvf /usr/local/bin nerdctl-1.7.7-linux-amd64.tar.gz`

#### buildkit

```shell
wget https://github.com/moby/buildkit/releases/download/v0.16.0/buildkit-v0.16.0.linux-amd64.tar.gz
wget https://github.com/moby/buildkit/releases/download/v0.16.0/buildkit-v0.16.0.linux-amd64.sbom.json && jq -r '.subject[]|(.digest.sha256+"  "+.name)' <buildkit-v0.16.0.linux-amd64.sbom.json >buildkit-v0.16.0.linux-amd64.tar.gz.sha256sum && rm buildkit-v0.16.0.linux-amd64.sbom.json
```

Note: for some reason, buildkit doesn't provide a normal digest

`sudo tar Cxzvf /usr/local buildkit-v0.16.0.linux-amd64.tar.gz`

```shell
wget https://raw.githubusercontent.com/moby/buildkit/v0.16.0/examples/systemd/system/buildkit.socket
wget https://raw.githubusercontent.com/moby/buildkit/v0.16.0/examples/systemd/system/buildkit.service
```

sudo install -D buildkit.socket /usr/local/lib/systemd/system/buildkit.socket<br />
sudo install -D buildkit.service /usr/local/lib/systemd/system/buildkit.service

```shell
sudo tee /etc/buildkitd.toml <<EOF
[worker.oci]
  enabled = false
[worker.containerd]
  enabled = true
EOF
```

#### service

```console
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl enable --now buildkit.socket
```

`sudo nerdctl version`

## Kubernetes

cpus=2
memory=2G

kubernetes
* containerd
* cri-tools
* kubernetes-cni
* kubeadm
* kubelet
* kubectl

### kubeadm

<https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/>

```shell
CRICTL_VERSION="v1.31.0"
ARCH="amd64"

wget https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz.sha256
```

`sudo tar -C /usr/local/bin -xzf crictl-${CRICTL_VERSION}-linux-amd64.tar.gz`

```shell
CNI_PLUGINS_VERSION="v1.3.0"
ARCH="amd64"

wget https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz
wget https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz.sha256
```

`sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz`

```shell
RELEASE="v1.31.2"
ARCH="amd64"

wget https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}
wget https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}.sha256
```

`sudo install kubeadm kubelet kubectl /usr/local/bin`

```shell
RELEASE_VERSION="v0.16.2"
sudo mkdir -p /usr/local/lib/systemd/system
wget https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service
sed -e "s:/usr/bin:/usr/local/bin:g" kubelet.service | sudo tee /usr/local/lib/systemd/system/kubelet.service
sudo mkdir -p /usr/local/lib/systemd/system/kubelet.service.d
wget https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf
sed -e "s:/usr/bin:/usr/local/bin:g" 10-kubeadm.conf | sudo tee /usr/local/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
```

```shell
systemctl enable --now kubelet
```

#### prerequisites

```shell
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-k8s.conf
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

sudo apt install -y socat conntrack

# configure CRI
sudo tee /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF

# configure CNI
sudo mkdir -p /etc/cni/net.d
sudo tee /etc/cni/net.d/10-containerd-net.conflist <<EOF
{
  "cniVersion": "1.0.0",
  "name": "containerd-net",
  "plugins": [
    {
      "type": "bridge",
      "bridge": "cni0",
      "isGateway": true,
      "ipMasq": true,
      "promiscMode": true,
      "ipam": {
        "type": "host-local",
        "ranges": [
          [{
            "subnet": "10.88.0.0/16"
          }],
          [{
            "subnet": "2001:4860:4860::/64"
          }]
        ],
        "routes": [
          { "dst": "0.0.0.0/0" },
          { "dst": "::/0" }
        ]
      }
    },
    {
      "type": "portmap",
      "capabilities": {"portMappings": true}
    }
  ]
}
EOF
```

#### init

```shell
KUBERNETES_VERSION="$(curl -sSL https://dl.k8s.io/release/stable-1.txt)"

sudo kubeadm config images list --kubernetes-version=${KUBERNETES_VERSION}
sudo kubeadm config images pull --kubernetes-version=${KUBERNETES_VERSION}
```

```text
registry.k8s.io/kube-apiserver:v1.31.2
registry.k8s.io/kube-controller-manager:v1.31.2
registry.k8s.io/kube-scheduler:v1.31.2
registry.k8s.io/kube-proxy:v1.31.2
registry.k8s.io/coredns/coredns:v1.11.1
registry.k8s.io/pause:3.9
registry.k8s.io/etcd:3.5.12-0
```

`sudo kubeadm init --apiserver-cert-extra-sans=127.0.0.1`

### kind

<https://kind.sigs.k8s.io/docs/user/quick-start>

```shell
wget https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
wget https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64.sha256sum
```

sudo install kind-linux-amd64 /usr/local/bin/kind

```shell
# extract the node image from the kind binary, since there is no real kind command to do it
IMAGE=$(strings $(command -v kind) | grep -o 'kindest/node:v[0-9.]*@sha256:[0-9a-f]\{64\}')

echo $IMAGE
sudo nerdctl pull $IMAGE && sudo nerdctl tag $IMAGE $(echo $IMAGE | cut -f1 -d@)
```

```text
kindest/node:v1.30.0@sha256:047357ac0cfea04663786a612ba1eaba9702bef25227a794b52890dd8bcd692e
```

`sudo kind create cluster`

### apiserver

Forward the port from the host over the user network: (static)

`-nic user,hostfwd=tcp::2222-:22,hostfwd=tcp::6443-:6443`

Tunnel the port over a ssh process in the background: (dynamic)

`ssh -L 6443:127.0.0.1:6443 -p 2222 ubuntu@127.0.0.1 &`

----

Written by Anders Björklund @afbjorklund
