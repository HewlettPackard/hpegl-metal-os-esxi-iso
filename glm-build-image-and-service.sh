#!/bin/bash
# (C) Copyright 2018-2022,2024 Hewlett Packard Enterprise Development LP

# This is the top level build script will take a ESXi install ISO and
# generate an ESXi service.yml file the can be imported as a Host OS into
# a GreenLake Metal portal.

# glm-build-image-and-service.sh does the following steps:
# * process command line arguments.
# * Customize the ESXi .ISO so that it works for GLM.  Run: glm-image-build.sh.
# * Generate GLM service file that is specific to $ESXI_VER. Run: glm-service-build.sh.

# glm-build-image-and-service.sh usage:
# glm-build-image-and-service.sh -i <esxi-iso-filename> -o <glm-custom-esxi-iso>
#    -v <esxi-version-number> -p <image-url-prefix> -s <glm-yml-service-file>

# command line options       | Description
# -------------------------- | -----------
# -i <esxi-iso-filename>     | local filename of the standard ESXi .ISO file
#                            | that was already downloaded. Used as input file.
# -------------------------- | -----------
# -v <esxi-version-number>   | a x.y ESXi version number.  Example: -v 7.9
# -------------------------- | -----------
# -r <esxi-rootpw>           | set the ESXi OS root password
# -------------------------- | -----------
# -o <glm-custom-esxi-iso>   | local filename of the GLM-modified ESXi .ISO file
#                            | that will be output by the script.  This file should
#                            | be uploaded to your web server.
# -------------------------- | -----------
# -p <image-url-prefix>      | the beginning of the image URL (on your web server).
#                            | Example: -p http://192.168.1.131.  The GLM service .YML
#                            | will assume that the image file will be available at
#                            | a URL constructed with <image-url-prefix>/<glm-custom-esxi-iso>.
# -------------------------- | -----------
# -s <glm-yml-service-file>  | local filename of the GLM .YML service file that
#                            | will be output by the script.  This file should
#                            | be uploaded to the GLM portal.
# -------------------------- | -----------
# -x <skip-test>             | [optional] Skip the test with "-x true"
#                            | By default this script will run the test "glm-test-service-image.sh"
#                            | script to verify that the upload was correct, and the size and checksum
#                            | of the ISO matches what is defined in the YML.
# -------------------------- | -----------

# NOTE: Make sure to upload the <glm-custom-esxi-iso> .ISO file to your web server to make it accessible
# at this constructed URL: # <image-url-prefix>/<glm-custom-esxi-iso>

# If the image URL can not be constructed with this simple mechanism, then you probably need to customize
# this script for a more complex URL construction.

# This script calls `glm-image-build.sh`, which needs the following packages to be installed on Debian/Ubuntu:
# Command: `sudo apt install genisoimage`

# To run the test script: glm-test-service-image.sh
#   By default this script will run the test script "glm-test-service-image.sh"
#   to verify that the upload was correct, and the size and checksum of the
#   ISO matches what is defined in the YML.
#   Example:
#     ./glm-build-image-and-service.sh                                       \
#     -i images/VMware-ESXi-7.0u3o-22348816-HPE-703.0.0.11.5.0.6-Jan2024.iso \
#     -v 7.0u3o                                                              \
#     -r PASSWORD                                                            \
#     -p https://10.152.3.96                                                 \
#     -o images/VMware-ESXi-7.0u3o-22348816-GLM.iso                          \
#     -s images/VMware-ESXi-7.0u3o-22348816-GLM.yml

set -euo pipefail

# ==================================================================================
# Prerequisites:
# ==================================================================================
# Required parameters for Image Web Server and test script "glm-test-service-image.sh"
#   WEB_SERVER_IP: IP address of web server to transfer ISO to (via SSH)
#   REMOTE_PATH:   Path on web server to copy files to
#   SSH_USER:      Username for SSH transfer
#   Note: Add your Linux test machine's SSH key to the Web Server
WEB_SERVER_IP="10.152.3.96"
REMOTE_PATH="/var/www/images/"
SSH_USER_NAME="root"
# ==================================================================================

# other required parameters
ESXI_ISO_FILENAME=""
GLM_CUSTOM_ESXI_ISO=""
ESXI_VER=""
ESXI_ROOTPW=""
IMAGE_URL_PREFIX=""
GLM_YML_SERVICE_FILE=""
GLM_YML_SERVICE_TEMPLATE=""
SKIP_TEST=""

while getopts "i:v:r:o:p:s:x:" opt
do
    case $opt in
        # required parameters
        i) ESXI_ISO_FILENAME=$OPTARG ;;
        v) ESXI_VER=$OPTARG ;;
        r) ESXI_ROOTPW=`openssl passwd -6 -salt xyz $OPTARG` ;;
        o) GLM_CUSTOM_ESXI_ISO=$OPTARG ;;
        p) IMAGE_URL_PREFIX=$OPTARG ;;
        s) GLM_YML_SERVICE_FILE=$OPTARG ;;
        x) SKIP_TEST=$OPTARG ;;
        *) echo "ERROR invalid parameter."; exit 1 ;;
     esac
done

# Check that required parameters exist.
if [ -z "$ESXI_ISO_FILENAME" -o \
     -z "$GLM_CUSTOM_ESXI_ISO" -o \
     -z "$ESXI_VER" -o \
     -z "$ESXI_ROOTPW" -o \
     -z "$IMAGE_URL_PREFIX" -o \
     -z "$GLM_YML_SERVICE_FILE" ]; then
  echo "script usage: $0 -i esxi-iso -v esxi-version -r esxi-rootpw" >&2
  echo "              -o glm-custom-esxi-iso -p http-prefix -s glm-yml-service-file" >&2
  exit 1
fi

if [[ ! -f $ESXI_ISO_FILENAME ]]; then
  echo "ERROR missing ISO image file $ESXI_ISO_FILENAME"
  exit 1
fi

# The clean function cleans up any lingering files
# that might be present when the script exits.
clean() {
  if [ ! -z "$GLM_YML_SERVICE_TEMPLATE" ]; then
    rm -f $GLM_YML_SERVICE_TEMPLATE
  fi
}

# By default this script will run the test "glm-test-service-image.sh" script
# to verify that the upload was correct, and the size and checksum of the
# ISO matches what is defined in the YML.
# Note: Set the Web Server related parameters at the top
#   User may verify SCP transfer using following commands:
#     $ echo bye | sftp -b - ${SSH_USER_NAME}@${WEB_SERVER_IP}
#     $ rsync -av --dry-run ${SOURCE} ${DESTINATION}
run_test() {
if [ "${SKIP_TEST}" != "true" ]; then
  # Run the test by default
   echo -e "\nCopying .ISO file to the web server..."
   SOURCE="${GLM_CUSTOM_ESXI_ISO}"
   DESTINATION="${SSH_USER_NAME}@${WEB_SERVER_IP}:${REMOTE_PATH}"
   echo "scp ${SOURCE} ${DESTINATION}"
   scp ${SOURCE} ${DESTINATION}
   if [ $? -ne 0 ]; then echo "ERROR scp failed to copy image"; exit 1; fi
   echo -e "\nRunning the test "glm-test-service-image.sh"..."
   echo "./glm-test-service-image.sh ${GLM_YML_SERVICE_FILE}"
   ./glm-test-service-image.sh ${GLM_YML_SERVICE_FILE}
fi
}

# Set a trap to call the clean function on exit
trap clean EXIT

# if the GLM customizied ESXi .ISO has not aleady been generated.
if [ ! -f $GLM_CUSTOM_ESXI_ISO ]; then
   # Customize the ESXi .ISO so that it works for GLM.
   GEN_IMAGE="sudo ./glm-image-build.sh \
      -i $ESXI_ISO_FILENAME \
      -o $GLM_CUSTOM_ESXI_ISO"
   echo $GEN_IMAGE
   $GEN_IMAGE
fi

GLM_YML_SERVICE_TEMPLATE=$(mktemp /tmp/glm-service.cfg.XXXXXXXXX)
ESXI_ISO=$(basename $ESXI_ISO_FILENAME)
sed "s/%ESXI_VERSION%/$ESXI_VER/g" glm-service.yml.template | \
  sed "s/%ESXI_ISO%/$ESXI_ISO/g" > $GLM_YML_SERVICE_TEMPLATE

# set root password in the KS configuration file using environment variable
sed -i "s'%ROOTPW%'$ESXI_ROOTPW'g" glm-kickstart.cfg.template

# Generate HPE GLM service file.
YYYYMMDD=$(date '+%Y%m%d')
GEN_SERVICE="./glm-service-build.sh \
  -s $GLM_YML_SERVICE_TEMPLATE \
  -o $GLM_YML_SERVICE_FILE \
  -c VMware \
  -f ESXi \
  -v $ESXI_VER-$YYYYMMDD-BYOI \
  -u $IMAGE_URL_PREFIX/$GLM_CUSTOM_ESXI_ISO \
  -d $ESXI_ISO_FILENAME \
  -i $GLM_CUSTOM_ESXI_ISO \
  -t glm-kickstart.cfg.template"
echo $GEN_SERVICE
$GEN_SERVICE

# unset root password in the KS configuration file
sed -i '/rootpw/c\rootpw --iscrypted %ROOTPW%' glm-kickstart.cfg.template

# By default run the test script "glm-test-service-image.sh" to verify ISO image
run_test

# print out instructions for using this image & service
NOTE="| |     
| |     IMPORTANT: Use the test (glm-test-service-image.sh) script to verify that
| |                the ISO upload was correct, and the size and checksum of the ISO
| |                match what is defined in the YML.
| |"

cat << EOF
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | ESXi ${GLM_CUSTOM_ESXI_ISO} will operate in evaluation mode for 60 days.
| | To use this ESXi ${GLM_CUSTOM_ESXI_ISO} after the evaluation period, you must register for a VMware product license.
| |
| | This build has generated a new Bare Metal ESXi service/image
| | that consists of the following 2 new files:
| |     $GLM_CUSTOM_ESXI_ISO
| |     $GLM_YML_SERVICE_FILE
| |
| | To use this new Bare Metal ESXi service/image in the HPE Bare Metal, take the following steps:
| | (1) Copy the new .ISO file ($GLM_CUSTOM_ESXI_ISO)
| |     to your web server ($IMAGE_URL_PREFIX) such that the file can be downloaded
| |     from the following URL: $IMAGE_URL_PREFIX/$GLM_CUSTOM_ESXI_ISO
`if [ "${SKIP_TEST}" == "true" ]; then echo "${NOTE}"; echo ; else echo "| |"; fi`
| | (2) Add the Bare Metal Service file ($GLM_YML_SERVICE_FILE) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe-gl-intg.com/). To add the HPE Metal Service file,
| |     sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| |
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
EOF

exit 0
