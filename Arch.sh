#!/bin/bash

# Prompt for root password
read -sp "Enter root password: " ROOT_PASSWORD
echo

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

# Partition the disk (replace /dev/sda with the appropriate device)
if [ "$BOOT_TYPE" = "UEFI" ]; then
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
	
	sleep 10s
	
	# Format the partitions
	mkfs.fat -F32 /dev/sda1
	mkfs.ext4 /dev/sda2
	
	# Mount the root partition
	mount /dev/sda2 /mnt

	# Mount the EFI partition
	mkdir -p /mnt/boot/efi
	mount /dev/sda1 /mnt/boot/efi
	
	sleep 10s
	
else
    (
      echo o      # create a new empty DOS partition table
      echo n      # add a new partition
      echo p      # primary partition
      echo        # default partition number (2)
      echo        # default start sector
      echo        # default end sector (entire disk)
      echo w      # write changes
    ) | fdisk /dev/sda
	
	sleep 10s
	
	# Format the partitions
	mkfs.ext4 /dev/sda1
	
	# Mount the root partition
	mount /dev/sda1 /mnt
	
	sleep 10s
fi


# Install base packages and kernel
pacstrap /mnt base base-devel linux linux-firmware

sleep 10s

# Generate fstab file
genfstab -U /mnt >> /mnt/etc/fstab

sleep 10s

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

sleep 10s

# Set the time zone
timedatectl set-timezone Asia/Kolkata

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



EOF

# Unmount all partitions
umount -R /mnt

echo "Installation completed successfully. You may now reboot the system."
reboot
