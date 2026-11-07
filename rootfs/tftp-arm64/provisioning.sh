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
