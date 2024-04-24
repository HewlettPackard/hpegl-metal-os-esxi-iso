#!/bin/bash
# (C) Copyright 2021-2022,2024 Hewlett Packard Enterprise Development LP
#
# This script will modify a VMware .iso file to automatically
# set the 'ks=cdrom:/KS.CFG' option. This option is described
# as follows (in the VMware documentation):
#    Performs a scripted installation with the script at path,
#    which resides on the CD in the CD-ROM drive. Each CDROM
#    is mounted and checked until the file that matches the
#    path is found.
#    Important:
#    If you have created an installer ISO image with a custom
#    installation or upgrade script, you must use uppercase
#    characters to provide the path of the script, for example,
#    ks=cdrom:/KS_CUST.CFG.

# Experimentation has show that the CDROM need to be a older
# type 1 CDROM image (mkisofs) in order for VMware to be able
# to read the CDROM!

# For additional information, see:
# VMware Boot Options
# https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.install.doc/GUID-9040F0B2-31B5-406C-9000-B02E8DA785D4.html#GUID-9040F0B2-31B5-406C-9000-B02E8DA785D4
# Create a VMware Installer ISO Image with a Custom Installation or Upgrade Script
# https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.install.doc/GUID-C03EADEA-A192-4AB4-9B71-9256A9CB1F9C.html#GUID-C03EADEA-A192-4AB4-9B71-9256A9CB1F9C

# Usage:
#  glm-image-build.sh -i <esxi.iso> -o <glm-customized-esxi.iso>

# command line options          | Description
# ----------------------------- | -----------
# -i <esxi.iso>                 | Input ESXI .ISO filename
# -o <glm-customized-esxi.iso>  | Output GLM ESXI .ISO file

set -e

# make sure we have enough permissions to mount .iso, etc
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

ISO_FILENAME=""
CUSTOM_ISO_FILENAME=""

# parse command line parameters
while getopts "i:o:" opt
do
  case $opt in
    i) ISO_FILENAME=$OPTARG ;;
    o) CUSTOM_ISO_FILENAME=$OPTARG ;;
  esac
done

if [ -z "$ISO_FILENAME" -o -z "$CUSTOM_ISO_FILENAME" ]; then
  echo "Usage: $0 -i <esxi.iso> -v <version> -o <glm-customized-esxi.iso>"
  exit 1
fi

if [[ ! -f $ISO_FILENAME ]]; then
  echo "ERROR missing image file $ISO_FILENAME"
  exit 1
fi

# Generate unique ID for use as the uploaded file name.
ID=$RANDOM
YYYYMMDD=$(date '+%Y%m%d')

ESXI_CDROM_MOUNT_POINT=/tmp/esxi-cdrom-mount
CUSTOM_ESXI_CDROM_DIR=/tmp/customized-esxi-cdrom

if [ ! -d ${ESXI_CDROM_MOUNT_POINT} ]; then
  mkdir ${ESXI_CDROM_MOUNT_POINT}
fi

mount -o loop $ISO_FILENAME ${ESXI_CDROM_MOUNT_POINT}

cp -r ${ESXI_CDROM_MOUNT_POINT} ${CUSTOM_ESXI_CDROM_DIR}
umount ${ESXI_CDROM_MOUNT_POINT}
rmdir ${ESXI_CDROM_MOUNT_POINT}

sed "s/^kernelopt=.*$/kernelopt=ks=cdrom:\/KS.CFG gdbPort=none logPort=none tty2Port=com2/" -i ${CUSTOM_ESXI_CDROM_DIR}/efi/boot/boot.cfg

echo Creating ${CUSTOM_ISO_FILENAME}
# generate a new customized vmware.iso
genisoimage -relaxed-filenames -J -R -o ${CUSTOM_ISO_FILENAME} \
   -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 \
   -boot-info-table -eltorito-alt-boot -e efiboot.img -no-emul-boot ${CUSTOM_ESXI_CDROM_DIR}

rm -rf ${CUSTOM_ESXI_CDROM_DIR}