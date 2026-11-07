#!/bin/sh

usage() {
    echo "Usage: $0 <architecture>" 1>&2;
    echo "" 1>&2;
    echo "Supporteted <architecture> are armhf, arm64, x86_64" 1>&2;
    exit 1;
}

while getopts "h" o; do
    case "${o}" in
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

ARCH=$1

if [ -z "$ARCH" ] ; then
    usage
fi

if [ "$ARCH" != "armhf" ] && [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "arm64" ] ; then
    echo "unsupported architecture"
    exit 1
fi

SERVER_armhf=https://cdimage.debian.org/pub/debian/dists/stretch/main/installer-armhf/current/images/netboot
LINUX_armhf=$SERVER_armhf/vmlinuz
INITRAMFS_armhf=$SERVER_armhf/initrd.gz

SERVER_arm64=https://cdimage.debian.org/pub/debian/dists/stretch/main/installer-arm64/current/images/netboot/debian-installer/arm64/
LINUX_arm64=$SERVER_arm64/linux
INITRAMFS_arm64=$SERVER_arm64/initrd.gz

SERVER_x86_64=https://cdimage.debian.org/pub/debian/dists/stretch/main/installer-amd64/current/images/netboot/debian-installer/amd64/
LINUX_x86_64=$SERVER_x86_64/linux
INITRAMFS_x86_64=$SERVER_x86_64/initrd.gz


download_kernel()
{
    if [ "$ARCH" = "armhf" ] ; then
	LINUX_URL=$LINUX_armhf
	INITRAMFS_URL=$INITRAMFS_armhf
    elif [ "$ARCH" = "arm64" ] ; then
	LINUX_URL=$LINUX_arm64
	INITRAMFS_URL=$INITRAMFS_arm64
    elif [ "$ARCH" = "x86_64" ] ; then
	LINUX_URL=$LINUX_x86_64
	INITRAMFS_URL=$INITRAMFS_x86_64
    fi

    if [ ! -e linux-"$ARCH" ] ; then
	wget $LINUX_URL -O linux-"$ARCH"
    fi

    if [ ! -e initrd-"$ARCH".gz ] ; then
	wget $INITRAMFS_URL -O initrd-"$ARCH".gz
    fi
}

create_disk() {
    if [ ! -e debian-"$ARCH".qcow2 ] ; then
	qemu-img create -f qcow2 debian-"$ARCH".qcow2 10G
    fi
}

setup_provisioning() {
    mkdir -p tftp-"$ARCH"

    if [ "$ARCH" = "armhf" ] ; then
	bootloader="
# Grub is the default boot loader (for x86). If you want lilo installed
# instead, uncomment this:
d-i grub-installer/skip boolean true
# To also skip installing lilo, and install no bootloader, uncomment this
# too:
d-i lilo-installer/skip boolean true
"
    elif [ "$ARCH" = "arm64" ] ; then
	bootloader="
# Boot loader installation.
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string /dev/vda
"
    elif [ "$ARCH" = "x86_64" ] ; then
	bootloader="
# Boot loader installation.
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string /dev/vda
"
    fi

    PKGS="curl openssh-server stress-ng bison flex wget \
time bc xz-utils build-essential ca-certificates kexec-tools kexec-tools \
lsb-release python"

    cat <<EOF > tftp-"$ARCH"/preseed.cfg
# Preconfiguration file for jessie.
# For more details see https://www.debian.org/releases/jessie/example-preseed.txt
d-i debian-installer/locale string en_US
d-i keyboard-configuration/xkb-keymap select us

# Choose an network interface that has link if possible.
d-i netcfg/choose_interface select auto

# Any hostname and domain names assigned from dhcp take precedence over
# values set here. However, setting the values still prevents the questions
# from being shown, even if values come from dhcp.
d-i netcfg/get_hostname string debian
d-i netcfg/get_domain string lan

# If you want to force a hostname, regardless of what either the DHCP
# server returns or what the reverse DNS entry for the IP is, uncomment
# and adjust the following line.
d-i netcfg/hostname string debian

# Disable that annoying WEP key dialog.
d-i netcfg/wireless_wep string

# Mirror settings.
d-i mirror/country string manual
d-i mirror/http/hostname string ftp.de.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

# Root account setup. You can set password in plain-text or pre-encrypted.
d-i passwd/root-password password root
d-i passwd/root-password-again password root

# User account setup.
#d-i passwd/make-user boolean false
d-i passwd/user-fullname string Build System
d-i passwd/username string build
d-i passwd/user-password password build
d-i passwd/user-password-again password build

# Controls whether or not the hardware clock is set to UTC.
d-i clock-setup/utc boolean true
# See the contents of /usr/share/zoneinfo/ for valid values.
d-i time/zone string Europe/Berlin
# Controls whether to use NTP to set the clock during the install.
d-i clock-setup/ntp boolean true

# Simple non-LVM, all files in one partition.
# For more examples see https://www.debian.org/releases/jessie/example-preseed.txt
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# Do not install recommended packages by default.
d-i base-installer/install-recommends boolean false
tasksel tasksel/first multiselect
# Individual additional packages to install. acpid and
# acpi-support-base are required to make virsh shutdown to work.
d-i pkgsel/include string ${PKGS}
popularity-contest popularity-contest/participate boolean false

d-i preseed/late_command string                                                     \
    in-target curl tftp://10.0.2.2/provisioning.sh -sSfo /tmp/provisioning.sh;	    \
    in-target sh -x /tmp/provisioning.sh

$bootloader

# Avoid that last message about the install being complete.
d-i finish-install/reboot_in_progress note

# Scan another CD or DVD?
# d-i apt-setup/use_mirror boolean false
d-i apt-setup/cdrom/set-first boolean false
d-i apt-setup/cdrom/set-next boolean false
d-i apt-setup/cdrom/set-failed boolean false

# Avoid that last message about the install being complete.
d-i finish-install/reboot_in_progress note

d-i cdrom-detect/load_media boolean no

# This will power off the machine instead of just halting it.
d-i debian-installer/exit/poweroff boolean true
EOF

    cat <<EOF > tftp-"$ARCH"/provisioning.sh
#!/bin/sh -x

sed -i 's,nullok_secure,nullok,' etc/pam.d/common-auth
echo "PermitRootLogin yes" >> etc/ssh/sshd_config
echo "PermitEmptyPasswords yes" >> etc/ssh/sshd_config
passwd -d root

# XXX Depeding on the run environment
echo "search lan" > /etc/resolv.conf
echo "nameserver 10.0.2.3" >> /etc/resolv.conf

mkdir -p /root/src
cd /root/src
wget https://mirrors.edge.kernel.org/pub/linux/kernel/tools/perf/v4.19.0/perf-4.19.0.tar.xz
tar xf perf-4.19.0.tar.xz
rm perf-4.19.0.tar.xz
ln -s perf-4.19.0 perf
exit 0
EOF
    chmod +x tftp-"$ARCH"/provisioning.sh
}

install_debian_armhf()
{
    checksum=$(md5sum tftp-"$ARCH"/preseed.cfg)
    args="console=ttyAMA0 \
	  auto=true preseed/url=tftp://10.0.2.2/preseed.cfg \
	  preseed/url/checksum=$checksum hostname=debian domain=lan"

    qemu-system-arm \
	-M virt -cpu cortex-a15 -m 256 \
	-drive file=debian-"$ARCH".qcow2,if=none,format=qcow2,id=hd0 \
	-device virtio-blk-device,drive=hd0 \
	-netdev user,id=net0,tftp=./tftp-"$ARCH" \
	-device virtio-net-device,netdev=net0,id=nic1 \
	-nographic -no-reboot \
	-kernel linux-"$ARCH" \
	-initrd initrd-"$ARCH".gz \
	-append "$args"
}

install_debian_arm64()
{
    checksum=$(md5sum tftp-"$ARCH"/preseed.cfg)
    args="console=ttyAMA0 \
	  auto=true preseed/url=tftp://10.0.2.2/preseed.cfg \
	  preseed/url/checksum=$checksum hostname=debian domain=lan"

    qemu-system-aarch64 \
	-M virt -cpu cortex-a57 -m 256 \
	-drive file=debian-"$ARCH".qcow2,if=none,format=qcow2,id=hd0 \
	-device virtio-blk-device,drive=hd0 \
	-netdev user,id=net0,tftp=./tftp-"$ARCH" \
	-device virtio-net-device,netdev=net0,id=nic1 \
	-nographic -no-reboot \
	-kernel linux-"$ARCH" \
	-initrd initrd-"$ARCH".gz \
	-append "$args"
}

install_debian_x86_64()
{
    checksum=$(md5sum tftp-"$ARCH"/preseed.cfg)
    args="console=ttyS0 auto=true preseed/url=tftp://10.0.2.2/preseed.cfg \
		preseed/url/checksum=$checksum hostname=debian domain=lan"

    qemu-system-x86_64 \
	-enable-kvm -cpu Haswell -m 1024  -smp 1 -m 256 \
	-drive file=debian-"$ARCH".qcow2,if=none,format=qcow2,id=hd0 \
	-device virtio-blk-pci,drive=hd0 \
	-netdev user,id=net0,tftp=./tftp-"$ARCH" \
	-device virtio-net-pci,netdev=net0,id=nic1 \
	-nographic -no-reboot \
	-kernel linux-"$ARCH" \
	-initrd initrd-"$ARCH".gz \
	-append "$args"
}

extract_rootfs()
{
#    reset
    mod=$(lsmod | grep nbd)
    if [ -z "$mod" ] ; then
	sudo modprobe nbd max_part=8
    fi
    mkdir -p debian-"$ARCH"

    sudo qemu-nbd --connect=/dev/nbd0 debian-"$ARCH".qcow2
    if [ "$ARCH" = "armhf" ] ; then
	sudo mount /dev/nbd0p2 debian-"$ARCH"
    elif [ "$ARCH" = "arm64" ] ; then
	sudo mount /dev/nbd0p1 debian-"$ARCH"
    elif [ "$ARCH" = "x86_64" ] ; then
	sudo mount /dev/nbd0p1 debian-"$ARCH"
    fi

    sudo tar -C debian-"$ARCH" \
	 --exclude="./var/cache/apt/archives" \
	 --exclude="./lib/modules" \
	 --exclude="./etc/fstab" \
	 -cpf debian-"$ARCH".tar .
    myid=$(id -u)
    sudo chown "$myid":"$myid" debian-"$ARCH".tar

    sudo umount debian-"$ARCH"
    sudo qemu-nbd --disconnect /dev/nbd0
}

download_kernel
create_disk
setup_provisioning
install_debian_"$ARCH"
extract_rootfs
