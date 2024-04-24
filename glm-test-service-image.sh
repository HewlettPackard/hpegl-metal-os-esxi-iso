#!/bin/bash
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP

# This is a script that will verify that the OS image referred to
# in a corresponding GLM OS service.yml is correct.  This script
# will verify that it can download the OS image and check its
# length (in bytes) and signature.  The script simulates what GLM
# DCC will do when it tries to download and verify an OS image.
# If this script fail then the service.yml file is most likely
# broken and will not work if loaded into GLM.

# Ways to use this script:
# * glm-test-service-image.sh glm-service.yml

set -euo pipefail

# The clean function cleans up any lingering files
# data that might be present when the script exits.
clean() {
    # remove the temp file
    rm -f $LOCAL_IMAGE_FILENAME
}

trap clean EXIT

usage() {
cat << EOF
script usage: $0 <service.yml>
EOF
}

# check command line arguements
if [[ $# -ne 1 ]]; then
  echo "bad command line args"
  usage
  exit 1
fi

# These are the lines that we are interested in from the service.yml file:
#  secure_url: "http://192.168.1.131/Windows_Server2019_custom-hpe-glm-20230123-29234.tar"
#  display_url: "Windows_Server2019_custom.iso"
#  file_size: 5360998400
#  signature: "750db9d2434faefd1cf2ec1b0f219541b594efa1a99202775e2e6431582ab4bf"
#  algorithm: sha256sum
eval $(egrep "file_size:|display_url:|secure_url:|signature:|algorithm:" $* | sed -e "s/^ *//" -e "s/: */=/")

# Check that required parameters exist.
# Allow $display_url to be optional.
if [ -z "$file_size" -o -z "$secure_url" -o \
     -z "$file_size" -o -z "$algorithm" ]; then
  usage
  exit 1
fi

# print image description that we found
echo "OS image file to be tested:"
echo "  Secure URL:" $secure_url
echo "  Display URL:" $display_url
echo "  Image size:" $file_size
echo "  Image signature:" $signature
echo "  Signature algorithm:" $algorithm

# make sure we have the tool for $algorithm
which $algorithm > /dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "$algorithm not found. Please install."
  exit -1
fi

# make temp filename
LOCAL_IMAGE_FILENAME="$(mktemp /tmp/os-image-XXXXXX.img)"

# download the image
echo
echo wget -O $LOCAL_IMAGE_FILENAME $secure_url
wget -O $LOCAL_IMAGE_FILENAME $secure_url
RC=$?
if [ $RC -ne 0 ]; then
    echo "wget failed to download image"
    exit 1
fi

# Verify image file exists.
stat ${LOCAL_IMAGE_FILENAME} > /dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
    echo "Image file '${LOCAL_IMAGE_FILENAME}' not found."
    exit 1
fi

# Get file size
SIZE=$(stat -L -c "%s" "$LOCAL_IMAGE_FILENAME")

# Check file size
if [ "$SIZE" -ne "$file_size" ]; then
   echo file size error. expected $file_size got $SIZE
   exit 1
fi
echo "Image Size has been verified (" $SIZE "bytes )"

# Calculate checksum
SUM=$($algorithm $LOCAL_IMAGE_FILENAME | sed "s/ .*//")

# Check checksum
if [ "$SUM" != "$signature" ]; then
   echo file checksum error. expected $signature got $SUM
   exit 1
fi
echo "Image Signature has been verified (" $SUM ")"

# success
echo The OS image size and signature have been verified

clean
