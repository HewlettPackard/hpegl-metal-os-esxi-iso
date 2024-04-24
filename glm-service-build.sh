#!/bin/bash
# (C) Copyright 2018-2022,2024 Hewlett Packard Enterprise Development LP
#
# This script generates a GreenLake Metal OS service.yml file
# appropriate for uploading to a GLM portal(s).
#
# Usage:
#  glm-service-build.sh -s <service-template> -o <service_yml_filename>
#      -c <svc_category> -f <scv_flavor> -v <svc_ver>
#      -d <display_url> -u <secure_url>
#      -i <local_image_filename> [ -t <os-template> ]
#
# command line options      | Description
# ------------------------- | -----------
# -s <service-template>     | service template filename (input file)
# -o <service_yml_filename> | service filename (output file)
# -c <svc_category>         | GreenLake Metal service category
# -f <scv_flavor>           | GreenLake Metal service flavor
# -v <svc_ver>              | GreenLake Metal service version
# -d <display_url>          | used to display the image URL in user interface
# -u <secure_url>           | the real URL to the image file
# -i <local_image_filename> | a full path to the image for this service.
#                           | Used to get the .ISO sha256sum and size
# [ -t <os-template> ]      | info template files. 1st -t option should be
#                           | %CONTENT1% in service-template. 2nd -> %CONTENT2%.

SED_SCRIPT_FILENAME=$(mktemp /tmp/sed.script.XXXXXXXX)
OS_TEMPLATE_COUNT=1

set -euo pipefail

SERVICE_TEMPLATE=""
LOCAL_IMAGE_FILENAME=""
OS_TEMPLATE_FILE=""
SVC_CATEGORY=""
SVC_FLAVOR=""
SVC_VER=""
SERVICE_YML_FILENAME=""
DISPLAY_URL=""
SECURE_URL=""

# Script Usage
usage() {
cat << EOF
    script usage: $0 -s <service-template> -o <service_yml_filename>
        -c <svc_category> -f <scv_flavor> -v <svc_ver>
        -d <display_url> -u <secure_url>
        -i <local_image_filename> [ -t <os-template> ]
EOF
exit 1
}

while getopts "o:c:f:d:i:s:t:v:u:" opt
do
    case $opt in
        s) SERVICE_TEMPLATE=$OPTARG ;;
        o) SERVICE_YML_FILENAME=$OPTARG ;;
        c) SVC_CATEGORY=$OPTARG ;;
        f) SVC_FLAVOR=$OPTARG ;;
        d) DISPLAY_URL=$OPTARG ;;
        u) SECURE_URL=$OPTARG ;;
        i) LOCAL_IMAGE_FILENAME=$OPTARG ;;
        v) SVC_VER=$OPTARG ;;
        t) OS_TEMPLATE_FILE=$OPTARG
            if [[ -z "$OS_TEMPLATE_FILE" ]]; then
                usage
            fi

            if [[ ! -f $OS_TEMPLATE_FILE ]]; then
                echo "ERROR missing OS template file ($OS_TEMPLATE_FILE)"
                exit 1
            fi
            # Encode the OS template file using base64 command with
            # no line wrap option (-w 0).  base64 can be installed using
            # "apt install sharutils" if needed.
            OS_TEMPLATE_CONTENT=$(/usr/bin/base64 -w 0 "$OS_TEMPLATE_FILE")
            # NOTE: base64 encoding output will be made of the following characters:
            # a-z, A-Z, 0-9, '/', '+', '='
            # (see https://en.wikipedia.org/wiki/Base64#Base64_table)
            # so we need to generate the sed command script without using
            # the normal '/' use '#' instead
            # https://stackoverflow.com/questions/16778667/how-to-use-sed-to-find-and-replace-url-strings-with-the-character-in-the-tar/16778711
            echo "s#%CONTENT${OS_TEMPLATE_COUNT}%#${OS_TEMPLATE_CONTENT}#g" >> $SED_SCRIPT_FILENAME
            let OS_TEMPLATE_COUNT+=1
            ;;
    esac
done

# The clean function cleans up any lingering files
# data that might be present when the script exits.
clean() {
    # Clean-up any intermediate files
    rm -f $SED_SCRIPT_FILENAME
}

trap clean EXIT

# Check that required parameters exist.
if [ -z "$SERVICE_TEMPLATE" -o -z "$SVC_CATEGORY" -o \
    -z "$SVC_FLAVOR" -o -z "$SVC_VER" -o -z "$SERVICE_YML_FILENAME" -o \
    -z "$DISPLAY_URL" -o -z "$SECURE_URL" -o -z "$LOCAL_IMAGE_FILENAME" ]; then
    usage
fi

if [[ ! -f $SERVICE_TEMPLATE ]]; then
    echo "ERROR missing service template file $SERVICE_TEMPLATE"
    exit 1
fi

if [[ ! -f $LOCAL_IMAGE_FILENAME ]]; then
    echo "ERROR missing image file $LOCAL_IMAGE_FILENAME"
    exit 1
fi

# Verify image file exists.
stat ${LOCAL_IMAGE_FILENAME} > /dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
    echo "Image file '${LOCAL_IMAGE_FILENAME}' not found."
    exit 1
fi

# Get file size & calculate checksum.
SIZE=$(stat -L -c "%s" "$LOCAL_IMAGE_FILENAME")
SUM=$(sha256sum $LOCAL_IMAGE_FILENAME | sed "s/ .*//")

# Sed treats '&' specially, so replacing '&' with '\&' in the URLs
SECURE_URL=`echo $SECURE_URL | sed "s/\&/\\\\\&/g"`
DISPLAY_URL=`echo $DISPLAY_URL | sed "s/\&/\\\\\&/g"`

# Generating the OS service YML file.
YYYYMMDD=$(date '+%Y%m%d')
echo "Generating the OS service YML file" $SERVICE_YML_FILENAME
sed "s/%YYYYMMDD%/${YYYYMMDD}/g" ${SERVICE_TEMPLATE} | \
 sed "s/%SUM%/${SUM}/g" | \
 sed "s/%SIZE%/${SIZE}/g" | \
 sed "s#%DISPLAY_URL%#${DISPLAY_URL}#g" | \
 sed "s#%SECURE_URL%#${SECURE_URL}#g" | \
 sed "s/%SVC_CATEGORY%/${SVC_CATEGORY}/g" | \
 sed "s/%SVC_FLAVOR%/${SVC_FLAVOR}/g" | \
 sed "s/%SVC_VER%/${SVC_VER}/g" | \
 sed -f $SED_SCRIPT_FILENAME > "$SERVICE_YML_FILENAME"

exit 0
