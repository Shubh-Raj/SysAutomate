#!/bin/bash


# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if the system uses UEFI or BIOS
if [[ -d /sys/firmware/efi/efivars ]]; then
    echo "UEFI system detected"
    BOOT_TYPE="UEFI"
else
    echo "BIOS system detected"
    BOOT_TYPE="BIOS"
fi

echo "Detected boot mode: $BOOT_TYPE"

# Update system clock
timedatectl set-ntp true

# Prompt for root password
read -sp "Enter root password: " ROOT_PASSWORD
echo


# Set the time zone
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

sleep 10s

# Generate locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

sleep 10s

# Set the hostname
echo "myhostname" > /etc/hostname

# Update hosts file
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 myhostname.localdomain myhostname" >> /etc/hosts

sleep 10s

# Install network manager
pacman -S networkmanager
systemctl enable NetworkManager

sleep 10s

# Install Wayland and desktop environment
pacman -S wayland wayland-protocols
git clone https://aur.archlinux.org/hyprland.git
cd hyprland
makepkg PKGBUILD

# Install bluetooth support
pacman -S bluez bluez-utils
systemctl enable bluetooth

# Install sudo and create user with sudo access
pacman -S sudo
read USERNAME
read -sp PASSWORD
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install nano text editor
pacman -S nano

read -p "Install the proprietary Nvidia driver? (y/n) " INSTALL_NVIDIA_DRIVER
if [[ $INSTALL_NVIDIA_DRIVER == "y" ]]; then
  pacman -S nvidia nvidia-utils
fi


if [ "$BOOT_TYPE" = "UEFI" ]; then
	(
	# Install and configure GRUB for UEFI
	pacman -S grub efibootmgr
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
	grub-mkconfig -o /boot/grub/grub.cfg
	)
	
else
	(
	# Install GRUB
	pacman -S grub

	# Install GRUB to the boot partition
	grub-install --target=i386-pc --boot-directory=/boot /dev/sda

	# Generate GRUB configuration file
	grub-mkconfig -o /boot/grub/grub.cfg

	)
fi

exit

# Unmount all partitions
umount -R /mnt

echo "Installation completed successfully. You may now reboot the system."
reboot
