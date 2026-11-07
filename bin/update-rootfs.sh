#!/bin/sh

cd /srv/www/htdocs/artifacts/rootfs

for arch in armhf arm64 x86_64; do
    rm -f debian-$arch.tar

    tar -C /srv/nfs/debian-$arch \
	-cpf debian-$arch.tar \
	--exclude proc/* \
	--exclude dev/* \
	--exclude sys/* \
	--exclude run/* \
	--exclude tmp/* \
	--exclude var/lib/apt/* \
	--exclude var/lib/dpkg/* \
	--exclude var/log/* \
	--exclude boot/* \
	--exclude home/* \
	--exclude lib/modules/* \
	--exclude usr/share/doc/* \
	--exclude usr/share/info/* \
	--exclude usr/share/man/* \
	.
done
