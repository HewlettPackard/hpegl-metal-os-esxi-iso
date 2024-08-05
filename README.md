<!-- (C) Copyright 2024 Hewlett Packard Enterprise Development LP -->

VMware ESXi Bring Your Own Image (BYOI) for HPE Private Cloud Enterprise - Bare Metal
=============================

* [Overview](#overview)
* [Example of manual build for reference](#example-of-manual-build-for-reference)
* [Building ESXi image](#building-esxi-image)
  *   [Setup Linux system for imaging build](#setup-linux-system-for-imaging-build)
  *   [Downloading recipe repo from GitHub](#downloading-recipe-repo-from-github)
  *   [Downloading ESXi ISO file](#downloading-esxi-iso-file)
  *   [Building the Bare Metal ESXi image and service](#building-the-bare-metal-esxi-image-and-service)
* [Customizing ESXi image](#customizing-esxi-image)
  *   [Modifying the way the image is built](#modifying-the-way-the-image-is-built)
* [Using the ESXi service and image](#using-the-esxi-service-and-image)
  *   [Adding ESXi service to Bare Metal portal](#adding-esxi-service-to-bare-metal-portal)
  *   [Creating an ESXi Host with ESXi Service](#creating-an-esxi-host-with-esxi-service)
  *   [Triage of image deployment problems](#triage-of-image-deployment-problems)
  *   [ESXi License](#esxi-license)
  *   [Network Setup](#network-setup)
* [Included tasks from this example Service](#included-tasks-from-this-example-service)
  *   [Minimal mgmt IPV4 network setup if secureboot is on](#minimal-mgmt-IPV4-network-setup-if-secureboot-is-on)
  *   [Alletra iSCSI adapter setup](#alletra-iscsi-adapter-setup)
  *   [Portgroup setup](#portgroup-setup)
* [Migrate Standard Switch to Distributed Switch](#migrate-standard-switch-to-distributed-switch)

----------------------------------

# Overview

This GitHub repository contains the script files, template files, and documentation for creating an ESXi service for HPE Bare Metal from an ESXi install .ISO file.  By building a custom image via this process, you can control the exact version of ESXi that is used and modify how ESXi is installed via a kickstart file.  Once the build is done, you can add your new service to HPE Bare Metal and deploy a host with that new image.

# Example of manual build for reference

Workflow for Building Image:

![image](https://github.com/hpe-hcss/bmaas-byoi-esxi-build/assets/90067804/a0dc9215-2be7-42bf-b4d0-6ed7f613d3a1)

Prerequisites:
```
1. You will need a Web Server with HTTPS support for storage of the HPE Base Metal images.  The Web Server is anything that:
   A. You have the ability to upload large .ISO image to and
   B. The Web Server must be on a network that will be reachable from the HPE On-Premises Controller.  When an OS service/image is used to create an HPE Bare Metal Host, the OS images will be downloaded via the secure URL in the service file.
   NOTE: For this manual build example, a local Web Server "http://10.152.2.125" is used for OS image storage.  For this example, we are assuming that the HPE Bare Metal OS images will be kept in: http://10.152.2.125/images/<.iso>.
2. Linux machine for building OS image
   A. Ubuntu 20.04.6 LTS
   B. Install supporting tools (git and genisoimage)
```

Step 1. Source code readiness  
A. Clone the GitHub Repo `hpegl-metal-os-esxi-iso`
```
git clone https://github.com/HewlettPackard/hpegl-metal-os-esxi-iso.git
```
B. Change directory to `hpegl-metal-os-esxi-iso`.

Step 2. Download the ESXi .ISO image to your local build environment via what ever method you prefer (Web Browser, etc)  
For example, we will assume that you have downloaded VMware-ESXi-7.0u3p-23307199-HPE.iso into the local directory.

Step 3. Run the script `glm-build-image-and-service.sh` to generate an output Bare Metal image .ISO as well as Bare Metal Service .yml:

Example:
```
./glm-build-image-and-service.sh \
  -v 7.0u3p \
  -p http://10.152.2.125 \
  -r qPassw0rd \
  -i VMware-ESXi-7.0u3p-23307199-HPE.iso \
  -o ESXi-7.0u3p-BareMetal.iso \
  -s ESXi-7.0u3p-BareMetal.yml
```

Example test result for reference:
```
+------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------
| | ESXi ESXi-7.0u3p-BareMetal.iso will operate in evaluation mode for 60 days.
| | To use this ESXi ESXi-7.0u3p-BareMetal.iso after the evaluation period,
| | you must register for a VMware product license.
| |
| | This build has generated a new Bare Metal ESXi service/image
| | that consists of the following 2 new files:
| |     ESXi-7.0u3p-BareMetal.iso
| |     ESXi-7.0u3p-BareMetal.yml
| |
| | To use this new Bare Metal ESXi service/image in the HPE Bare Metal, take the
| | following steps:
| | (1) Copy the new .ISO file (ESXi-7.0u3p-BareMetal.iso)
| |     to your web server (https://<web-server-address>)
| |     such that the file can be downloaded from the following URL:
| |     https://<web-server-address>/ESXi-7.0u3p-BareMetal.iso
| | (2) Use the script "glm-test-service-image.sh" to test that the HPE Bare Metal
| |     service .yml file points to the expected OS image on the web server with
| |     the expected OS image size and signature.
| | (3) Add the Bare Metal Service file to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe-gl-intg.com/). To add the HPE Bare Metal
| |     Service file, sign in to the HPE Bare Metal Portal and select the Tenant
| |     by clicking "Go to tenant". Select the Dashboard tile "Metal Consumption"
| |     and click on the Tab "OS/application images". Click on the button
| |     "Add OS/application image" to Upload the OS/application YML file.
| | (4) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------
+------------------------------------------------------------------------------------
```

Step 4. Copy the output Bare Metal image .ISO to the Web Server.

Step 5. Run the script `glm-test-service-image.sh`, which will verify that the OS image referred to in a corresponding Bare Metal OS service .yml is correct:
> **_NOTE:_** This script will verify that it can download the OS image and check its length (in bytes) and signature.
> The script simulates what the HPE On-Premises Controller will do when it tries to download and verify an OS image.
> If this script fails then the Bare Metal OS service .yml file is most likely broken and will not work if loaded into Bare Metal.

Example:
```
./glm-test-service-image.sh ESXi-7.0u3p-BareMetal.yml
```

Test result for reference:
```
OS image file to be tested:
  Secure URL: http://10.152.2.125/images/ESXi-7.0u3p-BareMetal.iso
  Display URL: images/VMware-ESXi-7.0u3p-23307199-HPE.iso
  Image size: 480323584
  Image signature: 98b29a9ecf9e9572cf9d34e5c57edcc2865c63ccf4eea9c5e846e0463d8fa04a
  Signature algorithm: sha256sum

wget -O /tmp/os-image-ARXIMa.img http://10.152.2.125/images/ESXi-7.0u3p-BareMetal.iso
--2024-03-18 23:22:12--  http://10.152.2.125/images/ESXi-7.0u3p-BareMetal.iso
Connecting to 10.79.90.46:80... connected.
Proxy request sent, awaiting response... 200 OK
Length: 480323584 (458M) [application/x-iso9660-image]
Saving to: ‘/tmp/os-image-ARXIMa.img’

/tmp/os-image-ARXIMa.img                      100%[================================================================================================>] 458.07M  21.1MB/s    in 21s

2024-03-18 23:22:33 (21.4 MB/s) - ‘/tmp/os-image-ARXIMa.img’ saved [480323584/480323584]

Image Size has been verified ( 480323584 bytes )
Image Signature has been verified ( 98b29a9ecf9e9572cf9d34e5c57edcc2865c63ccf4eea9c5e846e0463d8fa04a )
The OS image size and signature have been verified
```

Step 6. Add the Bare Metal service .yml file to the appropriate Bare Metal portal.

To add the Bare Metal service .yml file, sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".  
Select the Dashboard tile "Metal Consumption" and click on the tab "OS/application images".  
Click on the button "Add OS/application image" to upload this service .yml file.  

Step 7. Create a new Bare Metal host using this OS image service.

To create a new Bare Metal host, sign in to the HPE Bare Metal Portal and select the Tenant by clicking "Go to tenant".  
Select the Dashboard tile "Metal Consumption" and click on the tab "Compute groups". Further, create a host using the following steps:    
a. First create a Compute Group by clicking the button "Create compute group" and fill in the details.  
b. Create a Compute Instance by clicking the button "Create compute instance" and fill in the details.


# Building ESXi image

These are the high-level steps required to generate the Bare Metal ESXi service:
* Set up a Linux system with 20-40GB of free file system space for the build
* Set up a local file transfer/storage tool (E.g. Local Web Server with HTTPS support) that Bare Metal can reach over the network.
* Install Git Version Control (git) and other ISO tools (genisoimage)
* Downloading recipe repo from GitHub
* Download an ESXi .ISO file
* Build the Bare Metal ESXi image/service

These are the high-level steps required to use this built Bare Metal ESXi service/image on Bare Metal:
* Copy the built Bare Metal ESXi .ISO image to your web server
* Add the Bare Metal ESXi .YML service file to the appropriate Bare Metal portal
* In Bare Metal, create a host using this ESXi image service

## Setup Linux system for imaging build

These instructions and scripts are designed to run on a Linux system. Further,
these instructions were developed and tested on a Ubuntu 20.04 VM,
but they should work on other distros/versions. The Linux host will need to have
the following packages installed for these scripts to run correctly:

Packages      | Description
------------- | ---------------------
git           | a source code management tool.
genisoimage   | this package creates ISO9660/Joliet/HFS filesystem with optional Rock Ridge attributes.

On Ubuntu 20.04 VM, the necessary packages can be installed with:

```
sudo apt install git genisoimage
```

> **_NOTE:_**  You must also have sudo (superuser do) capability so that you can mount the ESXi ISO
> and copy the files from it to generate a new ESXi .ISO file for Bare Metal.

The resulting ESXi .ISO image file from the build, needs to be uploaded to a web server that
the HPE On-Premises Controller can access over the network.  More about this later.

## Downloading recipe repo from GitHub

Once you have an appropriate Linux environment setup, then download this recipe from GitHub
for building the HPE Bare Metal ESXi by:

```
git clone https://github.com/HewlettPackard/hpegl-metal-os-esxi-iso.git
```

## Downloading ESXi .ISO file

Next, you will need to manually download the appropriate ESXi .ISO onto the Linux system.
If you don't already have a source for the ESXi .ISO files, then you might want to sign up
for a VMware Customer Connect account at https://customerconnect.vmware.com/account-registration.

> **_NOTE:_**  You may complete the registration form to access VMware Customer Connect.
> VMware Customer Connect simplifies the management of free trials, downloads, and support.

This ESXi recipe has been successfully tested with the following version of ESXi:
* ESXi 7.0-U3o
* ESXi 7.0-U3p

> **_NOTE:_**  This recipe has not been tested on ESXi 5.0 and ESXi 6.0.

## Building the Bare Metal ESXi image and service

At this point, you should have a Linux system with:
* a copy of this repo
* a standard ESXi .ISO file

We are almost ready to do the build, but we need to know something about your environment.
When the build is done, it will generate two files:
* a Bare Metal modified ESXi .ISO file that needs to be hosted on a web server.
  It is assumed that you have (or can set up) a local web server that Bare Metal can reach over the network.
  You will also need login credentials on this web server, so that you can upload the files.
* a Bare Metal service .YML file that will be used to add the ESXi service to the portal.
  This .YML file will have a URL to the Bare Metal modified ESXi .ISO file on the web server.

The build needs to know what URL can be used to download the Bare Metal modified ESXi .ISO file.
We assume that the URL can be broken into 2 parts: \<image-url-prefix\>/\<bare-metal-custom-esxi-iso\>

If the image URL can not be constructed with this simple mechanism, then you probably need to
customize this script for a more complex URL construction.

So you can run the build with the following command line parameters:

```
./glm-build-image-and-service.sh \
    -i <esxi-iso-filename> \
    -v <esxi-version-number> \
    -r <esxi-rootpw> \
    -p <image-url-prefix> \
    -o <esxi-baremetal-iso> \
    -s <esxi-baremetal-service-file>
```

When an ESXi host is created in the Bare Metal portal, the HPE On-Premises Controller will pull down this Bare Metal modified ESXi .ISO file.

### glm-build-image-and-service.sh - top-level build script

This is the top-level build script that will take an ESXi install ISO and generate an ESXi service .yml file that can be imported as a Host OS into a Bare Metal portal.

This script 'glm-build-image-and-service.sh' does the following steps:
* process command line arguments.
* Customize the ESXi .ISO so that it works for Bare Metal.  Run: `glm-image-build.sh`
* Generate the Bare Metal service file for this Bare Metal image that we just generated. Run: `glm-service-build.sh`

Usage:

```
glm-build-image-and-service.sh \
    -i <esxi-iso-filename> \
    -v <esxi-version-number> \
    -r <esxi-rootpw> \
    -p <image-url-prefix> \
    -o <esxi-baremetal-iso> \
    -s <esxi-baremetal-service-file>
```

Command Line Options         | Description
-----------------------------| -----------
-i \<esxi-iso-filename\>     | local filename of the standard ESXi .ISO file that was already downloaded. Used as input file.
-v \<esxi-version-number\>   | a x.y ESXi version number.  Example: -v 7.9
-o \<esxi-baremetal-iso\>   | local filename of the Bare Metal modified ESXi .ISO file that will be output by the script. This file should be uploaded to your web server.
-p \<image-url-prefix\>      | the beginning of the image URL (on your web server). Example: -p https://<web-server-address>.
-s \<esxi-baremetal-service-file\>  | local filename of the Bare Metal .YML service file that will be output by the script. This file should be uploaded to the Bare Metal portal.

> **_NOTE:_**  The users of this script are expected to copy the \<esxi-baremetal-iso\> .ISO file to your web server
> such that the file is available at this constructed URL: \<image-url-prefix\>/\<esxi-baremetal-iso\>

### glm-image-build.sh - Customize ESXi.ISO for Bare Metal

This script `glm-image-build.sh` will repack an ESXi .ISO file for a Bare Metal ESXi install service that uses Virtual Media to
get the installation started.

The following changes are being made to the ESXi .ISO:
  1. configure to use a kickstart file on the iLO vmedia-cd and to pull the RPM packages (stage2) over vmedia
  2. setup for a text-based install (versus a GUI install)
  3. set up the console to the iLO serial port (/dev/ttyS1)
  4. eliminate the 'media check' when installing so that we get faster deployments (and parity with TGZ installs)

The ESXi .ISO is configured to use a kickstart file on the iLO vmedia-cd by adding the 'inst.ks=hd:sr0:/ks.cfg' option in
GRUB (used in UEFI) and isolinux (used in BIOS) configuration files. This option configures the ESXi installer to pull the
kickstart file from the root of the cdrom at /ks.cfg.  This kickstart option is setup by modifying the following files
on the .ISO:
  isolinux/isolinux.cfg for BIOS
  EFI/BOOT/grub.cfg for UEFI

Usage:
```
glm-image-build.sh \
    -i <esxi.iso> \
    -o <esxi-baremetal.iso>
```

Command Line Options      | Description
------------------------- | -----------
-i \<esxi.iso\>           | Input ESXi .ISO filename
-o \<esxi-baremetal.iso\> | Output Bare Metal ESXi .ISO file

Example:
```
sudo ./glm-image-build.sh \
    -i VMware-ESXi-7.0u3p-23307199-HPE.iso \
    -o ESXi-7.0u3p-BareMetal.iso
```

Here are the detailed changes that are made to the ESXi .ISO:
* change the default timeout to 5 seconds (instead of 60 seconds)
* change the default menu selection to the 1st entry (no media check)
* add the 'init.ks=hd:sr0:/ks.cfg' option to the various lines in the file
* also setup the serial console to ttyS1 (iLO serial port) with 115200 baud
* remove the 'quiet' option so the user can watch kernel loading and use to triage any problems

### glm-service-build.sh - Generate Bare Metal .YML service file

This script `glm-service-build.sh` generates a Bare Metal OS service .yml file appropriate for uploading to a Bare Metal portal(s).

Usage:
```
glm-service-build.sh \
    -s <service-template> \
    -o <service_yml_filename> \
    -c <svc_category> \
    -f <scv_flavor> \
    -v <svc_ver> \
    -d <display_url> \
    -u <secure_url> \
    -i <local_image_filename> [ -t <os-template> ]
```

Command Line Options        | Description
--------------------------- | -----------
-s \<service-template\>     | service template filename (input file)
-o \<service_yml_filename\> | service filename (output file)
-c \<svc_category\>         | the Bare Metal service category
-f \<scv_flavor\>           | the Bare Metal service flavor
-v \<svc_ver\>              | the Bare Metal service version
-d \<display_url\>          | used to display the image URL in the user interface
-u \<secure_url\>           | the real URL to the image file
-i \<local_image_filename\> | a full path to the image for this service. Used to get the .ISO sha256sum and size.
[ -t \<os-template\> ]      | info template files. 1st -t option should be %CONTENT1% in service-template. 2nd -> %CONTENT2%.

Example:
```
./glm-service-build.sh \
    -s /tmp/glm-service.cfg.RPmVhIbQf \
    -o ESXi-7.0u3p-BareMetal.yml \
    -c VMware \
    -f ESXi \
    -v 7.0-U3o-20240306-BYOI \
    -u http://10.152.2.125/images/ESXi-7.0u3p-BareMetal.iso \
    -d ESXi-7.0u3p-BareMetal.iso \
    -i VMware-ESXi-7.0u3p-23307199-HPE.iso \
    -t glm-kickstart.cfg.template
```

### glm-test-service-image.sh - Verify the Bare Metal OS image

This script `glm-test-service-image.sh` will verify that the OS image referred to in a corresponding Bare Metal OS service. yml is correct.

Usage:
```
glm-test-service-image.sh <esxi-baremetal-service-file>
```

Command Line Options            | Description
------------------------------- | -----------
\<esxi-baremetal-service-file\> | service filename (output file)

Example:
```
./glm-test-service-image.sh ESXi-7.0u3p-BareMetal.yml
```

# Customizing ESXi image

The ESXi image/service can be customized by:
* Modifying the way the image is built
* Modifying the ESXi kickstart file

## Modifying the way the image is built

Here is a description of the files in this repo:

Filename                       | Description
------------------------------ | -----------
README.md                      | This documentation
glm-build-image-and-service.sh | This is the top level build script will take an ESXi install ISO and generate an ESXi service .yml file that can be imported as a Host OS into a Bare Metal portal.
glm-image-build.sh             | This script will repack ESXi .ISO file for a Bare Metal ESXi install service that uses Virtual Media to get the installation started.
glm-service-build.sh           | This script generates a Bare Metal OS service .yml file appropriate for uploading the service to a Bare Metal portal(s).
glm-test-service-image.sh      | This is a script that will verify that the OS image referred to in a corresponding Bare Metal OS service .yml is correct.
glm-kickstart.cfg.template     | The core ESXi kickstart file (templated with install-env-v1)
glm-service.yml.template       | This is the Bare Metal .YML service file template.

Feel free to modify these files to suit your specific needs. General changes that you want to contribute back via a pull request are much appreciated.

## Modifying the ESXi kickstart file

The ESXi kickstart file is the basis of the automated install of ESXi supplied by this recipe.
Many additional changes to either of the kickstart files are possible to customize to your needs.

# Using the ESXi service and image

## Adding ESXi service to Bare Metal portal

When the build script completes successfully, you will find the following instructions to add this image to your HPE Bare Metal portal.
For example:

```
+------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------
| | ESXi ESXi-7.0u3p-BareMetal.iso will operate in evaluation mode for 60 days.
| | To use this ESXi ESXi-7.0u3p-BareMetal.iso after the evaluation period,
| | you must register for a VMware product license.
| |
| | This build has generated a new Bare Metal ESXi service/image
| | that consists of the following 2 new files:
| |     ESXi-7.0u3p-BareMetal.iso
| |     ESXi-7.0u3p-BareMetal.yml
| |
| | To use this new Bare Metal ESXi service/image in the HPE Bare Metal,
| | take the following steps:
| | (1) Copy the new .ISO file (ESXi-7.0u3p-BareMetal.iso)
| |     to your web server (https://<web-server-address>)
| |     such that the file can be downloaded from the following URL:
| |     https://<web-server-address>/ESXi-7.0u3p-BareMetal.iso
| | (2) Use the script "glm-test-service-image.sh" to test that the HPE
| |     Bare Metal service .yml file points to the expected OS image on the
| |     Web Server with the expected OS image size and signature.
| | (3) Add the Bare Metal Service file to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe-gl-intg.com/). To add the HPE
| |     Bare Metal Service file, sign in to the HPE Bare Metal Portal and
| |     select the Tenant by clicking "Go to tenant". Select the Dashboard tile
| |     "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the
| |     OS/application YML file.
| | (4) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------
+------------------------------------------------------------------------------------
```
Follow the instructions as directed!

## Creating an ESXi Host with ESXi Service

Create a host in Bare Metal using this OS image service.

## Triage of image deployment problems

After you have created your custom ESXi image/server and created a host using this new service, you will want to monitor the deployment so for the first few times, make sure things are going as expected.
Here are some points to note:
  * This image/service is set to output to the serial console during ESXi deployment and watching the serial console is the easiest way to monitor the ESXi deployment/installation.
  * HPE GreeLake Metal tools do not monitor the serial port(s) at this time so if an error is generated by the ESXi installer, the Bare Metal tools will not know about it.
  * Sometimes for more difficult OS deployment problems you might want to gain access to the servers iLO so that you can monitor it that way. See your Bare Metal administrator.

## ESXi License

ESXi is a licensed software and users need to have a valid license key from VMware to use ESXi.
This install service does nothing to set up an ESXi license key in any way.  Users are expected to manually use ESXi tools to set up an ESXi license on the host.

> **_NOTE:_** ESXi will operate in evaluation mode and this license will expire in 60 days.
> To use this ESXi ESXi-7.0u3p-BareMetal.iso after the evaluation period, you must register for a VMware product license.

## Network Setup

> **_NOTE:_** Have access to ESXi host client using URL `https://<ESXi-Host-IP>/ui/#/host`.
> Have SSH to this ESXi host using root login.
> The ESXi shell is enabled on this host. Also, the SSH is enabled on this host.

Get version information for vmkernel. Also, get release-level information:  
```
[root@esxi:~] vmware -vl
VMware ESXi 7.0.3 build-22348816
VMware ESXi 7.0 Update 3

[root@esxi:~] uname -a
VMkernel esxi.esxi.localdomain 7.0.3 #1 SMP Release build-22348816 Aug 30 2023 04:36:58 x86_64 x86_64 x86_64 ESXi
```

ESXi host’s NICs (uplink adapters) information:  
```
[root@esxi:~] esxcfg-nics -l
Name    PCI          Driver      Link Speed      Duplex MAC Address       MTU    Description
vmnic0  0000:0f:00.0 nmlx5_core  Up   25000Mbps  Full   88:e9:a4:6b:b8:54 1500   Mellanox Technologies MT27800 Family [ConnectX-5]
vmnic1  0000:0f:00.1 nmlx5_core  Up   25000Mbps  Full   88:e9:a4:6b:b8:55 1500   Mellanox Technologies MT27800 Family [ConnectX-5]
```

ESXi host's virtual network adapters (VMkernel NICs IPv4 & IPv6) information:  
```
[root@esxi:~] esxcfg-vmknic -l
Interface  Port Group/DVPort/Opaque Network        IP Family IP Address                              Netmask         Broadcast       MAC Address       MTU     TSO MSS   Enabled Type                NetStack 
vmk0       Management Network                      IPv4      172.26.64.10                            255.255.255.192 172.26.64.63    88:e9:a4:6b:b8:54 1500    65535     true    STATIC              defaultTcpipStack
vmk0       Management Network                      IPv6      fe80::8ae9:a4ff:fe6b:b854               64                              88:e9:a4:6b:b8:54 1500    65535     true    STATIC, PREFERRED   defaultTcpipStack
```

ESXi host's route information:  
```
[root@esxi:~] esxcfg-route
VMkernel default gateway is 172.26.64.1

[root@esxi:~] esxcfg-route -l
VMkernel Routes:
Network          Netmask          Gateway          Interface
172.26.64.0      255.255.255.192  Local Subnet     vmk0
default          0.0.0.0          172.26.64.1      vmk0

[root@esxi:~] esxcli network ip route ipv4 list
Network      Netmask          Gateway      Interface  Source
-----------  ---------------  -----------  ---------  ------
default      0.0.0.0          172.26.64.1  vmk0       MANUAL
172.26.64.0  255.255.255.192  0.0.0.0      vmk0       MANUAL
```

ESXi host's virtual switches information:  
```
[root@esxi:~] esxcfg-vswitch -l
Switch Name      Num Ports   Used Ports  Configured Ports  MTU     Uplinks
vSwitch0         8960        4           128               1500    vmnic0

  PortGroup Name                            VLAN ID  Used Ports  Uplinks
  VM Network                                0        0           vmnic0
  Management Network                        0        1           vmnic0
```

ESXi host's DNS information:  
```
[root@esxi:~] esxcli network ip dns server list
   DNSServers: 10.1.64.20, 10.1.65.20
```

Host network setup should happen automatically. To validate the network connectivity with vmkping:  
```
[root@esxi:~] vmkping -I vmk0 172.26.64.1
PING 172.26.64.1 (172.26.64.1): 56 data bytes
64 bytes from 172.26.64.1: icmp_seq=0 ttl=255 time=0.856 ms
64 bytes from 172.26.64.1: icmp_seq=1 ttl=255 time=0.932 ms
64 bytes from 172.26.64.1: icmp_seq=2 ttl=255 time=0.986 ms

--- 172.26.64.1 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.856/0.925/0.986 ms
```

ESXi host's default Firewall information:  
```
[root@esxi:~]  esxcli network firewall get
   Default Action: DROP
   Enabled: true
   Loaded: true
```
# Included tasks from this example Service
## Minimal mgmt IPV4 network setup if secureboot is on
the VM Management network is setup in the early phase of install so the machine will be online even with secure boot on.
## Alletra iSCSI adapter setup
If one or more storage volume is attached with host create, the volumes will be available and ready to use.
## Portgroup setup
* The following Port Group can be created by this service by including the corresponding networks during host creation. The port group type is determined by (purpose tag) of each network.
### FS MGMT (vmKernel)
* This is the same Management Network **_NOTE:_** No default VM Network is created
* vmk Nic (vmk0) is setup with IP Pool information
### iSCSI-A (iSCSI-A) and iSCSI-B (iSCSI-B)
* vmk Nic is setup with IP Pool information
* iSCSI software adapter created
* host iqn populated
* CHAP user/secret populated
* MTU set to 9000
### vMotion (vMotion)
* vmk Nic is setup with IP Pool information
* hostsvc/vmotion/vnic_set
### vmFT
* vmk Nic is setup with IP Pool information
* hostsvc/advopt/update FT.Vmknic updated
### Telemetry (Telemetry)
* vmk Nic is setup with IP Pool information
* A ReadOnly User "telemetry" is created
### vCHA (vCHA)
### Backup (Backup)
## Steps to migrate Standard Switch to Distributed Switch
```
+------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------
| | Create a Distributed Switch with 2 uplinks
| | Create Port Groups on Distributed Switch for migration
| | For each host migrating to Distributed Switch
| | (1) Add host to vDS
| | (2) Remove one of the 2 physical NIC on Standard Switch for Distributed VSwitch to use as uplink
| | (3) Assign port group for each vmk NICs on this host
| | (4) With desired config confirmed, remove the remaining physical NIC and add it as 2nd uplink of the Distributed VSwitch
| +----------------------------------------------------------------------------------
+------------------------------------------------------------------------------------
```
