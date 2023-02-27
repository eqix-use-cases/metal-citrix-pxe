#!/usr/bin/env bash

apt-get upgrade -y
apt-get install dnsmasq nginx pxelinux syslinux-common -y
#echo 'DNSMASQ_OPTS="-p0"' >> /etc/default/dnsmasq
rm /etc/nginx/sites-enabled/default

tee -a /etc/nginx/sites-enabled/default > /dev/null <<-EOD
server {
    listen 80 default_server;
    server_name _;
    root /opt/netboot;
    location / {
        autoindex on;
    }
}
EOD

nginx -t
systemctl restart nginx

mkdir -p /opt/netboot
tftp_root=/opt/netboot
wget https://mirrors.xcp-ng.org/isos/8.2/xcp-ng-8.2.1.iso -P $tftp_root

tee -a /etc/dnsmasq.conf > /dev/null <<-EOD
no-resolv
server=147.75.207.207
server=147.75.207.208
EOD


tee -a /etc/dnsmasq.d/dhcp.conf > /dev/null <<-EOD

# DHCP
interface=bond0,lo
bind-interfaces
dhcp-range=bond0,192.168.100.100,192.168.100.200
dhcp-option=6,147.75.207.207,147.75.207.208

# PXE config
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=/opt/netboot

# UEFI booting
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-match=set:efi-x86,option:client-arch,6
dhcp-boot=tag:efi-x86_64,bootx64.efi
dhcp-boot=tag:efi-x86,bootx64.efi
EOD

#systemctl stop systemd-resolved
#systemctl disable systemd-resolved

# citrix
mkdir /mnt/CHV
mount /opt/netboot/xcp-ng-8.2.1.iso /mnt/CHV
cp -rT /mnt/CHV /opt/netboot/CHV
cat /opt/netboot/CHV/.treeinfo
cp -rT /opt/netboot/CHV/EFI /opt/netboot/EFI
cp -rT /opt/netboot/CHV/boot /opt/netboot/boot
cp /opt/netboot/CHV/install.img /opt/netboot/

tee -a /opt/netboot/CHV-answer.xml > /dev/null <<-EOD
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
EOD

sed -i 's+bootx64.efi+/EFI/xenserver/grubx64.efi+g' /etc/dnsmasq.d/dhcp.conf
systemctl restart dnsmasq
mv /opt/netboot/EFI/xenserver/grub.cfg /opt/netboot/EFI/xenserver/grub.cfg.bak

tee -a /opt/netboot/EFI/xenserver/grub.cfg > /dev/null <<-EOD
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
    module2 /boot/vmlinuz console=ttyS1 console=hvc0 answerfile_device=eth0 answerfile=http://$(curl https://metadata.platformequinix.com/2009-04-04/meta-data/public-ipv4)/CHV-answer.xml install
    module2 /install.img
}
EOD