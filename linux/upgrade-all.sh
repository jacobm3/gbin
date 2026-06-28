# Install nala first if it isn't already present, since the upgrade below uses it.
if ! command -v nala >/dev/null 2>&1; then
	sudo apt-get update
	sudo apt-get install -y nala
fi

sudo nala upgrade --full
sudo snap refresh
