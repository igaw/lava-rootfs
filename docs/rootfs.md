g# Build rootfs

## Install kas

    git clone git@github.com:siemens/kas.git

or
    pip3 install kas

## Build rootfs

Not tested yet:

   kas build kas-bbb.yml
   kas build kas-minnowboard.yml



# create-rootfs.sh

## remove kernel image from image
the kernel package will interfear with apt udpate/upgrade on an nfs rootfs

- x86_64
apt-get purge grub-common
apt remove linux-image-*
apt autoremove

- armhf

apt remove linux-image-4.9.0-8-armmp-lpae


# ansible

ansible-playbook -i production rttests.yaml
