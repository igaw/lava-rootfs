#!/bin/bash -x

PRJPATH=$(pwd)
BUILDPATH=$(pwd)/build

download_packages()
{
    echo "download packages for rootfs"

    sudo rm -rf build/debian-$ARCH
    mkdir -p build/debian-$ARCH

    DEBPKG=systemd,systemd-sysv,udev,iproute2,ssh,vim,inetutils-ping,ntpdate,less,curl,openssh-server,bison,flex,wget,time,bc,xz-utils,build-essential,ca-certificates,kexec-tools,lsb-release,python,net-tools
    #DEBPKG=systemd,systemd-sysv,udev,ssh,openssh-server

    sudo qemu-debootstrap \
	 --arch=$ARCH \
	 --variant=minbase \
	 --include=$DEBPKG \
	 stretch \
	 build/debian-$ARCH \
	 http://ftp.de.debian.org/debian/
    # qemu-static?
    # sudo chroot build/debian-$ARCH apt-get clean
    sudo rm -rf build/debian-$ARCH/var/lib/apt/lists/*
}

setup_rootfs()
{
    echo "static rootfs provisioning"

    pushd . > /dev/null

    cd $BUILDPATH/debian-$ARCH/

    echo "debian" | sudo tee etc/hostname > /dev/null

    sudo sed -i 's,^root:\*:,root::,' etc/shadow
    sudo sed -i 's,nullok_secure,nullok,' etc/pam.d/common-auth
    echo "PermitRootLogin yes" | sudo tee -a etc/ssh/sshd_config > /dev/null
    echo "PermitEmptyPasswords yes" | sudo tee -a etc/ssh/sshd_config > /dev/null

    sudo ln -fs /dev/null etc/systemd/network/99-default.link
    sudo ln -fs lib/systemd/system/systemd-networkd.service etc/systemd/system/multi-user.target.wants/systemd-networkd.service
    sudo ln -fs lib/systemd/system/serial-getty@.service etc/systemd/system/getty.target.wants/serial-getty@ttyS4.service
    sudo ln -fs lib/systemd/system/serial-getty@.service etc/systemd/system/getty.target.wants/serial-getty@uart8250,io,0xdf00,115200n8.service

    sudo cp $PRJPATH/debian-overlay/resolv.conf etc/resolv.conf

    popd > /dev/null
}

tar_rootfs()
{
    echo "create rootfs tar file"

    sudo rm -rf debian-$ARCH.tar
    
    sudo tar -C $BUILDPATH/debian-$ARCH \
	--exclude proc/* \
	--exclude dev/* \
	--exclude sys/* \
	--exclude run/* \
	--exclude tmp/* \
	--exclude var/log/* \
	--exclude boot/* \
	--exclude home/* \
	--exclude lib/modules/* \
	--exclude usr/share/doc/* \
	--exclude usr/share/info/* \
	--exclude usr/share/man/* \
	-cpf debian-$ARCH.tar .
}

usage() {
    echo "Usage $0"
    echo " -s		skip debian rootfs creation"
    exit 1
}

build_debian_rootfs=1

while getopts "s" o; do
    case "${o}" in
	s)
	    build_debian_rootfs=0 ;;
        *)
            usage ;;
    esac
done
shift $((OPTIND-1))

ARCH=$1

if [ -z "$ARCH" ] ; then
    echo "ARCH argument expected"
    exit 1
fi

if [ $build_debian_rootfs -eq 1 ] ; then
    download_packages
fi

setup_rootfs
tar_rootfs
