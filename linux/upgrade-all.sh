# upgrade-all.sh — one command to fully update this machine: apt packages (via
# nala) plus any snaps.
#
# HOW TO RUN:  ~/gbin/linux/upgrade-all.sh   (it sudo's the steps that need root)
# PREREQUISITES: internet access; sudo rights. nala is auto-installed if absent.
# RISK: upgrades every package, which may restart services or pull a new kernel.
#
# (No shebang on purpose — run it with bash/sh or source it.)

# nala is a friendlier front-end to apt (parallel downloads + an undo history).
# command -v checks whether the `nala` command exists; redirecting both stdout
# and stderr to /dev/null hides its output so we only care about the exit code.
# The leading ! inverts it: "if nala is NOT found, install it first".
if ! command -v nala >/dev/null 2>&1; then
	# Refresh the package index, then install nala (-y auto-confirms).
	sudo apt-get update
	sudo apt-get install -y nala
fi

# Upgrade all apt packages. --full lets it add/remove packages when a dependency
# requires it (the equivalent of apt full-upgrade / dist-upgrade).
sudo nala upgrade --full
# Update any installed snap packages too (no-op if snapd isn't used).
sudo snap refresh
