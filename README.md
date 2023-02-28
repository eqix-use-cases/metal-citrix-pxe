# terraform-provider-template
Template repository for terraform modules

## Table of Contents
- [Pre-requirement](#pre-requirements)
- [Usage](#usage)

## Pre-requirements

↥ [back to top](#table-of-contents)

- [Terraform](https://www.terraform.io/downloads.html)
- [Equinix Metal](https://console.equinix.com/)

## Usage

↥ [back to top](#table-of-contents)

The full examples are in the `examples` folder. The basic usage would be

```bash
terraform init
terraform apply
```

destroy the infrastructure 

```bash
terraform destroy
```

# Overview

This will deploy infrastructure to deploy Citrix [Open Source Hypervisor](https://xcp-ng.org/#easy-to-install) over netboot.

download the installation media 

```bash
wget https://mirrors.xcp-ng.org/isos/8.2/xcp-ng-8.2.1.iso
```

mount the ISO to extract content 

```
mkdir /mnt/CHV
mount <path_to_CHV_ISO> /mnt/CHV
```

copy Contents of ISO to directory under nginx webroot

```
cp -rT /mnt/CHV /opt/netboot/CHV
```

validate that the '.treeinfo' file is copied

```
cat /opt/netboot/CHV/.treeinfo
```

output example
```
[platform]  
name = XCP
version = 3.2.1

[branding]
name = Citrix Hypervisor
version = 8.2.1

[build]
number = release/yangtze/master/58

[keys]
key1 = RPM-GPG-KEY-CH-8
key2 = RPM-GPG-KEY-CH-8-LCM
key3 = RPM-GPG-KEY-Platform-V1
```

## Check the server and boot file structure setup

test access to the CHV directory from the webserver by navigating a browser to the URL
```
http://IP_OF_YOUR_SERVER/CHV/
```

copy the following files/directories to the tftp root directory from /opt/netboot/CHV/

copy the entire EFI directory and its contents

```
cp -rT /opt/netboot/CHV/EFI /opt/netboot/EFI
```

copy the boot directory

```
cp -rT /opt/netboot/CHV/boot /opt/netboot/boot
```

copy the install.img file

```
cp /opt/netboot/CHV/install.img /opt/netboot/
```

create a CHV Install Answer file in the nginx webroot directory

```
/opt/netboot/CHV-answer.xml
```

example 

```xml
<installation srtype="ext">
  <primary-disk>sda</primary-disk>
  <keymap>us</keymap>
  <root-password type="hash">your_password_hash_here</root-password>
  <source type="url">http://<YOUR_SERVER_IP>/CHV/</source>
  <admin-interface name="eth0" proto="dhcp"/>
  <ntp-server>pool.ntp.org</ntp-server>
  <name-server>8.8.8.8</name-server>
  <name-server>8.8.4.4</name-server>
  <timezone>Etc/Gmt</timezone>
</installation>
```

edit the /etc/dnsmasq.d/dhcp.conf file to point at XCP grubx64.efi file in the EFI/xenserver/ directory

```
sed -i 's+bootx64.efi+/EFI/xenserver/grubx64.efi+g' /etc/dnsmasq.d/dhcp.conf
systemctl restart dnsmasq
```

create a grub.cfg file to configure Metal SOS console output and include CHV answerfile

```
mv /opt/netboot/EFI/xenserver/grub.cfg /opt/netboot/EFI/xenserver/grub.cfg.bak
vi /opt/netboot/EFI/xenserver/grub.cfg
```

paste in the following for starters, fill in the CHV answerfile IP http server address as appropriate and also ensure that the first NIC is specified after answerfile_device=, some plan types based on SMC hardare have onboard 10gbase-t NICs that show up as eth0/1 in the OS, so the first sfp+ NIC would be eth2 (m3.small for example)

```bash
set default="0"

function load_video {
  insmod efi_gop
  insmod efi_uga
  insmod video_bochs
  insmod video_cirrus
  insmod all_video
}

load_video
set gfxpayload=keep
insmod gzio
insmod part_gpt
insmod ext2

set timeout=5

menuentry "install" {
    multiboot2 /boot/xen.gz dom0_max_vcpus=1-16 dom0_mem=max:8192M com2=115200,8n1 console=com2
    module2 /boot/vmlinuz console=ttyS1 console=hvc0 answerfile_device=eth0 answerfile=http://<Server_IP_Address>/CHV-answer.xml install
    module2 /install.img
}
```

## Provisioning instance(s) to boot from L2 PXE

provision your Equinix Metal instance with Custom iPXE with no iPXE Script URL using the following Userdata, be sure to enter your server IP

```
#!ipxe

set dhcp_server YOUR_SERVER_IP

:retry_dhcp
dhcp
ping --count 1 ${dhcp_server} || goto retry_dhcp
```

> This is an example when you deploy via netboot using PXE and userdata
