#!/bin/bash 

# Ensure the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

# Update package lists
echo "Updating package lists..."
apt update -y

# Install required packages
echo "Installing required packages: "
apt install -y git nano curl wget vim bash-completion xterm iputils-ping dnsutils qemu-guest-agent mtr net-tools iperf3 tmux tcpdump apt-utils jq gpg bridge-utils traceroute nmap iptables-persistent tree

# Set timezone to Asia/Riyadh
echo "Setting timezone to Asia/Riyadh..."
timedatectl set-timezone Asia/Riyadh

# Enable bash completion
echo "Enabling bash completion..."
echo "source /etc/profile.d/bash_completion.sh" >> ~/.bashrc
source ~/.bashrc

# Enable and start qemu-guest-agent
echo "Enabling and starting qemu-guest-agent..."
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent

# Stop and disable systemd-resolved
echo "Stopping and disabling systemd-resolved..."
systemctl stop systemd-resolved
systemctl disable systemd-resolved

# Remove the default /etc/resolv.conf file
echo "Removing the default /etc/resolv.conf file..."
rm -f /etc/resolv.conf

# Create a new /etc/resolv.conf with nameserver 8.8.8.8
echo "Creating a new /etc/resolv.conf with nameserver 8.8.8.8..."
echo -e "nameserver 8.8.8.8" > /etc/resolv.conf

# Add custom PS1 and rsz function to both root and srvadmin users
for user in root srvadmin; do
    user_bashrc="/home/$user/.bashrc"
    [ "$user" = "root" ] && user_bashrc="/root/.bashrc"

    echo "Updating .bashrc for $user..."

    cat << 'EOF' >> "$user_bashrc"

export PS1="\[\e[31m\][\[\e[m\]\[\e[38;5;172m\]\u\[\e[m\]@\[\e[38;5;153m\]\h\[\e[m\] \[\e[38;5;214m\]\W\[\e[m\]\[\e[31m\]]\[\e[m\]\\$ "

rsz() {
	if [[ -t 0 && $# -eq 0 ]];then
		local IFS='[;' escape geometry x y
		echo -ne '\e7\e[r\e[999;999H\e[6n\e8'
		read -t 5 -sd R escape geometry || {
			echo unsupported terminal emulator. >&2
			return 1
		}
		x="${geometry##*;}" y="${geometry%%;*}"
		if [[ ${COLUMNS} -eq "${x}" && ${LINES} -eq "${y}" ]];then
			echo "${TERM} ${x}x${y}"
		elif [[ "$x" -gt 0 && "$y" -gt 0 ]];then
			echo "${COLUMNS}x${LINES} -> ${x}x${y}"
			stty cols ${x} rows ${y}
		else
			echo unsupported terminal emulator. >&2
			return 1
		fi
	else
		echo 'Usage: rsz'
	fi
}



EOF

done

# Notify completion
echo "Setup complete!"
