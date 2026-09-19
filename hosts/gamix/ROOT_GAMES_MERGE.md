# Merging the root and Games partitions (live USB runbook)

Context: `gamix`'s root partition (`nvme0n1p5`, 65.6G ext4) kept running out
of space because of the Nix store, while the separate Games partition
(`nvme0n1p4`, 1.2T ext4, mounted at `/home/arne/Games`) had hundreds of GB
free. Rather than bind-mounting individual paths (`/nix`, etc.) onto the
Games partition, the chosen fix is to delete the small root partition
entirely, merge its former space into the Games partition, and make *that*
partition root — with the old Games files ending up as a normal directory
at `/home/arne/Games` instead of a separate mount.

This can't be done live: it requires deleting the partition the running
system boots from. It has to be done from a NixOS installer live USB.

The config in this repo (`hardware-configuration.nix`'s `fileSystems."/"`,
and the removal of the separate `fileSystems."/home/arne/Games"` entry in
`configuration.nix`) already reflects the post-merge layout, so the copied
root just needs `nixos-rebuild boot` run against it once the partition work
below is done.

**Before starting:** back up anything irreplaceable off this disk. The
mechanics below don't need external storage (701G free on the Games
partition is enough headroom to do the whole reorg in place), but deleting
a partition is inherently risky and a real backup is the only safety net if
a command is mistyped.

## Partition/UUID reference

| Partition | Size | Role (before) | Role (after) |
|---|---|---|---|
| `nvme0n1p1` | ~100M | EFI (`/boot`), UUID `F657-B6E4` | unchanged |
| `nvme0n1p2` | 16M | Windows MSR | unchanged |
| `nvme0n1p3` | 586G | Windows NTFS | unchanged |
| `nvme0n1p4` | 1.2T | Games, ext4, UUID `c8a9b8f2-74f1-42b9-88b0-86853c3c6544` | becomes root |
| `nvme0n1p5` | 65.6G | root, ext4, UUID `0f8bb05d-85dc-498a-9ef0-5042af2224b9` | **deleted**; space absorbed into p4 |

ext4 resize (growing) doesn't change the filesystem UUID, so `p4`'s UUID
(`c8a9b8f2-...`) stays valid as the new root's UUID throughout.

## Phase 1 — Boot the live USB, confirm layout

Boot the NixOS installer USB (UEFI mode, matching normal boot). Get a root
shell (`sudo -i` works passwordless on the installer), then confirm the
disk still looks as expected:

```sh
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL,MOUNTPOINT,UUID
```

Compare against the table above. If anything differs, stop and reassess
before continuing.

## Phase 2 — Mount both filesystems

```sh
sudo mkdir -p /mnt/oldroot /mnt/newroot
sudo mount -o ro /dev/nvme0n1p5 /mnt/oldroot     # old root, read-only for safety
sudo mount /dev/nvme0n1p4 /mnt/newroot           # Games partition, becomes new root
```

## Phase 3 — Stage existing Games files out of the way

The Games partition's filesystem root currently holds game files directly;
that space is needed for the OS tree. Move the existing content into a temp
folder (same-filesystem rename, instant, no data copied):

```sh
sudo mkdir /mnt/newroot/.games-migrate
cd /mnt/newroot
sudo bash -c 'shopt -s dotglob; for f in *; do [ "$f" = ".games-migrate" ] && continue; mv -- "$f" .games-migrate/; done'
ls -la /mnt/newroot          # should now show only .games-migrate (and maybe lost+found)
```

## Phase 4 — Copy the entire old root onto the Games partition

```sh
sudo rsync -aHAX --info=progress2 \
  --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp --exclude=/mnt \
  /mnt/oldroot/ /mnt/newroot/
```

`-H` preserves hardlinks (critical — this is how `/nix/store` dedups),
`-A -X` preserve ACLs/xattrs. This copies ~53G including the full Nix
store, so it takes a while. Then recreate the excluded runtime mountpoints
as empty dirs:

```sh
sudo mkdir -p /mnt/newroot/{proc,sys,dev,run,tmp}
```

## Phase 5 — Put the Games files back, in their final place

```sh
sudo mkdir -p /mnt/newroot/home/arne/Games      # should already exist from the copy; harmless if so
sudo bash -c 'shopt -s dotglob; for f in /mnt/newroot/.games-migrate/*; do mv -- "$f" /mnt/newroot/home/arne/Games/; done'
sudo rmdir /mnt/newroot/.games-migrate
```

## Phase 6 — Sanity check before going further

```sh
du -sh /mnt/oldroot /mnt/newroot
ls /mnt/newroot/home/arne/Games | head          # games should be here
ls -la /mnt/newroot/home/arne/Games/swapfile    # confirm the swapfile made it, right size (~34G)
grep -A2 'fileSystems."/"' /mnt/newroot/home/arne/nixos-config/hosts/gamix/hardware-configuration.nix
```

That last command should show UUID `c8a9b8f2-...`. If anything looks
wrong, **stop here** — nothing destructive has happened yet; you can
unmount and rethink.

## Phase 7 — Delete the old root partition, grow the Games partition into it

```sh
sudo umount /mnt/oldroot
sudo umount /mnt/newroot
sudo parted /dev/nvme0n1 print free       # confirm p5 is still there, last on disk
sudo parted /dev/nvme0n1 rm 5
sudo parted /dev/nvme0n1 resizepart 4 100%
sudo partprobe /dev/nvme0n1
sudo e2fsck -f /dev/nvme0n1p4
sudo resize2fs /dev/nvme0n1p4
```

This is the point of no return — after `parted rm 5`, the old root
partition is gone.

## Phase 8 — Remount, install the bootloader against the new root

```sh
sudo mount /dev/nvme0n1p4 /mnt/newroot
df -h /mnt/newroot                              # should now show ~1.2T+ total
sudo mount /dev/nvme0n1p1 /mnt/newroot/boot      # EFI partition — untouched by any of this
sudo nixos-enter --root /mnt/newroot
```

Now chrooted into the merged system:

```sh
cd /home/arne/nixos-config
git status                                       # confirm the config edits are present
nixos-rebuild boot --flake .#gamix
```

This installs the kernel/initrd/loader entry for the new root UUID onto
`/boot` — which was never touched by any of the steps above; it's the same
96M EFI partition as always.

## Phase 9 — Exit, unmount, reboot

```sh
exit                                             # leave the chroot
sudo umount -R /mnt/newroot
sudo reboot
```

Remove the USB when it restarts.

## Phase 10 — Verify, then fix hibernation

Once booted normally:

```sh
df -h /                                          # should show ~1.2T+, way more free space
ls /home/arne/Games                              # games should be exactly where they were
```

`boot.kernelParams`'s `resume_offset` needs recomputing — the swapfile was
only renamed (not rewritten) during the migration, but the filesystem
resize that grew the partition is reason enough to double check rather than
assume the old offset still holds:

```sh
sudo filefrag -v /home/arne/Games/swapfile | head -5
```

Take the physical offset of the first extent (in 4K blocks), update
`boot.kernelParams` in `hosts/gamix/configuration.nix`, then:

```sh
sudo nixos-rebuild switch --flake ~/nixos-config#gamix
```

Test hibernate/resume once before trusting it. Once everything checks out,
commit the corrected `resume_offset` and delete this file (or leave it as
a record — your call).

## If something goes wrong mid-way

Up through Phase 6 (before `parted rm 5` in Phase 7), nothing is
destructive — just unmount everything and stop to reassess. After
Phase 7, the old root partition is gone, so recovery means fixing forward
(`nixos-enter`/bootloader troubleshooting from the live USB) rather than
rolling back. That's the point where the backup mentioned at the top
matters.
