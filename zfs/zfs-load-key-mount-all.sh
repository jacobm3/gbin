
# ---------------------------------------------------------------------------
# zfs-load-key-mount-all.sh
#
# What it does:
#   Unlocks every encrypted ZFS dataset and then mounts all ZFS filesystems.
#   Handy after a reboot when encrypted datasets come up locked and unmounted.
#
# How to run:
#   ./zfs-load-key-mount-all.sh
#   (No arguments. You may be prompted for the encryption passphrase if a
#    dataset's keysource is a passphrase rather than a key file.)
#
# Prerequisites:
#   - ZFS installed with at least one pool/dataset.
#   - sudo/root privileges (loading keys and mounting need root).
# ---------------------------------------------------------------------------

# Load encryption keys for ALL encrypted datasets.
#   load-key  : provide the key so an encrypted dataset can be used.
#   -a        : apply to all datasets (otherwise you'd name one). If a key
#               comes from a passphrase, ZFS will prompt you here.
sudo zfs load-key -a
# Mount every ZFS filesystem that is set to be mounted.
#   mount -a : mount all (skips ones already mounted or marked canmount=off).
#              Encrypted datasets can only mount after their key is loaded,
#              which is why load-key runs first above.
sudo zfs mount -a
