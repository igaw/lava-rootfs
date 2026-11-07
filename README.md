# lava-rootfs

Earlier attempts at a rootfs for LAVA boards, from 2017 to 2022. They're kept
for reference and none of them is in use.

**The rootfs the health jobs use today wasn't built from this repo.** It's
`lava-image.<arch>-1.tar.xz` from
[igaw/lava-artifacts](https://github.com/igaw/lava-artifacts), built with
KIWI NG from [igaw/kiwi-lava](https://github.com/igaw/kiwi-lava) (openSUSE
Tumbleweed). That repo's overlay files are identical in the x86_64 archive.

| Path | Approach |
|---|---|
| `bin/create-rootfs-debootstrap.sh` | Debian, debootstrap |
| `bin/create-rootfs-debian-installer.sh`, `rootfs/tftp-arm64/` | Debian, installer with preseed |
| `rootfs/kas-*.yml` | kas; `docs/rootfs.md` says "Not tested yet" |
| `ansible/`, `ansible-rootfs/` | installs the test packages on a Debian system |
| `bin/update-rootfs.sh` | packs `/srv/nfs/debian-<arch>` into tars on the old artifact server |
