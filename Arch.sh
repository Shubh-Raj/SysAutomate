#!/bin/bash

# Prompt for root password
read -sp "Enter root password: " ROOT_PASSWORD
echo

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Update system clock
timedatectl set-ntp true

# Prompt for username and password
read -p "Enter username: " USERNAME
read -sp "Enter password: " PASSWORD
echo

# Partition the disk (replace /dev/sda with the appropriate device)
(
  echo g      # create a new empty GPT partition table
  echo n      # add a new partition
  echo        # default partition number (1)
  echo        # default start sector (2048)
  echo +512M  # partition size
  echo EF00   # partition type (EFI system)
  echo n      # add a new partition
  echo        # default partition number (2)
  echo        # default start sector
  echo        # default end sector (entire disk)
  echo        # default partition type (Linux filesystem)
  echo w      # write changes
) | fdisk /dev/sda

# Format the partitions
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2

# Mount the root partition
mount /dev/sda2 /mnt

# Install base packages and kernel
pacstrap /mnt base base-devel linux linux-firmware

# Generate fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set the time zone
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

# Generate locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set the hostname
echo "myhostname" > /etc/hostname

# Update hosts file
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 myhostname.localdomain myhostname" >> /etc/hosts

# Install network manager
pacman -S networkmanager
systemctl enable NetworkManager

# Install Wayland and desktop environment
pacman -S wayland wayland-protocols
pacman -S hyprland

# Install bluetooth support
pacman -S bluez bluez-utils
systemctl enable bluetooth

# Install sudo and create user with sudo access
pacman -S sudo
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install nano text editor
pacman -S nano

EOF

# Unmount all partitions
umount -R /mnt

echo "Installation completed successfully. You may now reboot the system."