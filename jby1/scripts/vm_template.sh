#!/bin/bash

set -e  # Exit on any command failure

# Variables
STORAGE="local-lvm"
MEMORY=4096
DISK_SIZE="5G"  # You can adjust this if needed
BRIDGE="V10"
IMAGES_DIR="/var/lib/vz/template/iso"  # Common image directory

# Function to download the cloud image if not already downloaded
download_cloud_image() {
    if [ -f "$CLOUD_IMAGE_PATH" ]; then
        echo "Cloud image already exists: $CLOUD_IMAGE_PATH"
        read -p "Do you want to use the existing image or download a fresh copy? (use/fresh): " CHOICE_IMAGE
        if [[ "$CHOICE_IMAGE" == "fresh" ]]; then
            echo "Removing old image..."
            rm -f "$CLOUD_IMAGE_PATH"
        else
            echo "Using existing image."
            return
        fi
    fi

    echo "Downloading cloud image..."
    wget "$CLOUD_IMAGE_URL" -O "$CLOUD_IMAGE_PATH"
}

# Function to create and configure the VM
create_vm() {
    qm create $TEMPLATE_ID --name $VM_NAME --cpu host --sockets 1 --cores 2 --memory $MEMORY --net0 virtio,bridge=$BRIDGE --agent 1 --ostype l26 --scsihw virtio-scsi-single
    qm importdisk $TEMPLATE_ID "$CLOUD_IMAGE_PATH" $STORAGE
    qm set $TEMPLATE_ID --scsi0 "$STORAGE:vm-$TEMPLATE_ID-disk-0"
    qm resize $TEMPLATE_ID scsi0 $DISK_SIZE
    qm set $TEMPLATE_ID --boot c --bootdisk scsi0
    qm set $TEMPLATE_ID --serial0 socket --vga serial0
}

# Function to configure the VM image
configure_vm_image() {
    local image="$1"
    local password_file="password_root.txt"
    
    # Prompt user for password
    read -sp "Enter root password: " ROOT_PASSWORD
    echo  # New line after password input

    # Save the password to a file
    echo "$ROOT_PASSWORD" > "$password_file"

    # Install packages and configure QEMU guest agent
    sudo virt-customize -a "$image" --install qemu-guest-agent
    sudo virt-customize -a "$image" --install nano
    sudo virt-customize -a "$image" --install xterm
    sudo virt-customize -a "$image" --run-command 'systemctl enable qemu-guest-agent'

    # Set root password
    sudo virt-customize -a "$image" --root-password file:"$password_file"

    # Create a new user
    sudo virt-customize -a "$image" --run-command "useradd -m -s /bin/bash srvadmin"
    sudo virt-customize -a "$image" --password srvadmin:file:"$password_file"
    sudo virt-customize -a "$image" --run-command "usermod -aG sudo srvadmin"

    # Update the image
    sudo virt-customize -a "$image" --update

    # Configure DHCP for the network
    sudo virt-customize -a "$image" \
      --run-command 'mkdir -p /etc/systemd/network' \
      --run-command 'cat > /etc/systemd/network/10-dhcp.network << EOF
[Match]
Name=ens18

[Network]
DHCP=yes
EOF'

    # Append to srvadmin's .bashrc
    sudo virt-customize -a "$image" \
      --run-command 'cat >> /home/srvadmin/.bashrc << EOF

alias rsz='\''resize >/dev/null'\'' 
if [ \$(tty) == '\''/dev/ttyS0'\'' ]; then 
   trap rsz DEBUG 
   export TERM=xterm 
fi
EOF'

    sudo virt-customize -a "$image" \
      --run-command 'cat >> /root/.bashrc << EOF

alias rsz='\''resize >/dev/null'\'' 
if [ \$(tty) == '\''/dev/ttyS0'\'' ]; then 
   trap rsz DEBUG 
   export TERM=xterm 
fi
EOF'
    
    # Cleanup password file
    rm -f "$password_file"

    echo "VM image configuration for $image completed."
}

# Menu for template selection
echo "Select a template to download:"
echo "1) Ubuntu 20.04"
echo "2) Ubuntu 22.04"
echo "3) Ubuntu 22.10"
echo "4) Ubuntu 24.04"
echo "5) Ubuntu 24.10"  # New option for Ubuntu 24.10
echo "6) CentOS 9"
echo "7) Rocky Linux 9"
echo "8) Alma Linux 9"
echo "9) Fedora 38"  # Updated numbering for other options
echo "10) Alpine Linux 3.19"  # New option for Alpine Linux
read -p "Enter the number of your choice: " CHOICE

# Set the cloud image URL, path, and template name based on user choice
case $CHOICE in
    1)
        CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/minimal/releases/focal/release/ubuntu-20.04-minimal-cloudimg-amd64.img"
        CLOUD_IMAGE_PATH="${IMAGES_DIR}/ubuntu-20.04-minimal-cloudimg-amd64.img"
        TEMPLATE_NAME="U2004"
        ;;
    2)
        CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img"
        CLOUD_IMAGE_PATH="${IMAGES_DIR}/ubuntu-22.04-minimal-cloudimg-amd64.img"
        TEMPLATE_NAME="U2204"
        ;;
    3)
        CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/minimal/releases/kinetic/release/ubuntu-22.10-minimal-cloudimg-amd64.img"
        CLOUD_IMAGE_PATH="${IMAGES_DIR}/ubuntu-22.10-minimal-cloudimg-amd64.img"
        TEMPLATE_NAME="U2210"
        ;;
    4)
        CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img"
        CLOUD_IMAGE_PATH="${IMAGES_DIR}/ubuntu-24.04-minimal-cloudimg-amd64.img"
        TEMPLATE_NAME="U2404"
        ;;
    5)
        CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/minimal/daily/oracular/current/oracular-minimal-cloudimg-amd64.img"
        CLOUD_IMAGE_PATH="${IMAGES_DIR}/oracular-minimal-cloudimg-amd64.img"  # Adjust path for the new image
        TEMPLATE_NAME="U2410"
        ;;
    6)
        CLOUD_IMAGE_URL="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
        CLOUD_IMAGE_PATH="${IMAGES_DIR}/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
        TEMPLATE_NAME="CentOS9"
        ;;
    7)
        CLOUD_IMAGE_URL="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
        CLOUD_IMAGE_PATH="${IMAGES_DIR}/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
        TEMPLATE_NAME="Rocky9"
        ;;
    8)
        CLOUD_IMAGE_URL="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
        CLOUD_IMAGE_PATH="${IMAGES_DIR}/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
        TEMPLATE_NAME="Alma9"
        ;;
    9)
        CLOUD_IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
        CLOUD_IMAGE_PATH="${IMAGES_DIR}/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
        TEMPLATE_NAME="Fedora38"
        ;;
    10)
        CLOUD_IMAGE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.2-x86_64-bios-cloudinit-r0.qcow2"
        CLOUD_IMAGE_PATH="${IMAGES_DIR}/nocloud_alpine-3.21.2-x86_64-bios-cloudinit-r0.qcow2"
        TEMPLATE_NAME="Alpine3212"
        ;;
    *)
        echo "Invalid choice! Exiting."
        exit 1
        ;;
esac

# Prompt for VM ID and name
while true; do
    read -p "Enter TEMPLATE_ID: " TEMPLATE_ID
    if [[ $TEMPLATE_ID =~ ^[0-9]+$ ]]; then
        break
    else
        echo "Invalid TEMPLATE_ID. Please enter a numeric value."
    fi
done

read -p "Enter VM_NAME: " VM_NAME

# Download the cloud image
download_cloud_image

# Check if the image is an Ubuntu version for customization
if [[ "$CHOICE" -ge 1 && "$CHOICE" -le 5 ]]; then
    read -p "Do you want to customize the image? (y/n): " CUSTOMIZE
    if [[ "$CUSTOMIZE" =~ ^[Yy]$ ]]; then
        configure_vm_image "$CLOUD_IMAGE_PATH"
    fi
fi

# Create and configure the VM
create_vm

echo "Cloud-init VM template for ${TEMPLATE_NAME} has been created with TEMPLATE_ID $TEMPLATE_ID"