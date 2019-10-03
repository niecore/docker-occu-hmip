# Docker OCCU (homematicIP)
![Logo](https://www.homematic-ip.com/downloads/hmip/grafik/logo.png)

This docker images provides a lightweight image for running a [homematicIP](https://www.homematic-ip.com) daemon (ReGaLess CCU).

As no WebUI is hosted, the management and integration of homematicIP devices is only possible by communicating with the XmlRPC interface. There are 3rd party tools available that allow you to  conveniently manage your "headless CCU". [Homematic Manager](https://github.com/hobbyquaker/homematic-manager) is a very good one.

The image is build on top of the [OCCU SDK](https://github.com/eq-3/occu). Device data is persisted to the _/data_ directory. The creation of a shared mount or volume is advised.

This image is optimized to be used with the [HmIP RF-USB](https://de.elv.com/elv-homematic-ip-arr-bausatz-rf-usb-stick-fuer-alternative-steuerungsplattformen-hmip-rfusb-fuer-smart-home-hausautomation-152306) stick as this device can be passed to the container without any kernel patches on the host. If you need to communicate with a PCB device connected to the Raspberry's GPIO, please check out Alex's [piVCCU](https://github.com/alexreinert/piVCCU) project. 

## How to build

### Build Parameter
| Argument | Default Value | Description
|--|--|--|
|OCCU_VERSION|3.47.10|Sets the OCCU version that will be downloaded and installed. Check https://github.com/eq-3/occu/releases for possible values. |
|HMIP_RFUSB_VERSION|2.8.6|Sets the version of the HmIP RF-USB firmware as the update requires the version to be part of the filename. |

```
docker build --tag occu-hmip .
```

## How to run
As already mentioned it's advised to map the persisted data folder to a shared folder or volume. Otherwise you will loose all your paired devices on a container reboot. In addition you need to share the USB device so the container can communicate with the device.

```
docker run -d -v <<PATH TO STORAGE>>:/data -p 2010:2010 --device=/dev/ttyUSB0:/dev/ttyUSB0 --name ccu occu-hmip
```

### Changing the USB port
If your device is running on a different port, you have to adjust the `crRFD.conf` as well as the `run.sh` script in order to launch the daemon and to update the firmware. After the adjustment, the image has to be rebuild.

_data/crRFD.conf_
```
34  Adapter.1.Port=/dev/ttyUSB0
```

_data/run.sh_
```
11  if [ ! -f /data/firmware_updated ]; then
12      java -Xmx64m -jar /opt/HmIP/hmip-copro-update.jar -p /dev/ttyUSB0 -f "${UPDATE_FILE}"
```

## USB Driver
If the USB device is not available on your host system, you probably need to load the driver for the USB serial converter. 

```
modprobe cp210x
sh -c 'echo 1b1f c020 > /sys/bus/usb-serial/drivers/cp210x/new_id' 
```

After running this commands your device is loaded and probably attached to _/dev/ttyUSB0_. You can run `dmesg | grep tty` to check the final device endpoint.

Of course you can also create a simple device rule to automatically load the driver after a reboot. Just create the following udev rule and reboot your Raspberry Pi / system.

_/lib/udev/rules.d/99-hmip-usb.rule_
```
ACTION=="add", ATTRS{idVendor}=="1b1f", ATTRS{idProduct}=="c020", RUN+="/sbin/modprobe cp210x" RUN+="/bin/sh -c 'echo 1b1f c020 > /sys/bus/usb-serial/drivers/cp210x/new_id'"
```

This image should also work on Windows devices as the image itself is multi platform compatible (Java). There is driver on the ELV homepage that should allow you to properly install the USB device. However, I've not tested this on my own.

## HmIP RF-USB Firmware update
The firmware update is applied automatically one the container is started for the first time. However, if the update failed or you want to force an additional update, just delete the `firmware_updated` file in your shared data folder.

## Full stack example
The following example shows how I compose my Smart Home stack. I'm running [Home Assistant](https://www.home-assistant.io/) which connects which variaos hardware platforms as well as with out HmIP daemon. Home Assistant provides a great user experiance, a big community and also allows me to expose all my non-supported devices to Apple Home. For automations, I love to use [Appdaemon](https://appdaemon.readthedocs.io/en/latest/) which allows you to create automations in code. I've also written a [tiny docker image](https://github.com/Horizon0156/docker-appdaemon) that shippes Appdaemon decoupled from the Home Assistant instance.

```
version: '3'
services:
  homeassistant:
    container_name: homeassistant
    image: homeassistant/raspberrypi3-homeassistant:stable
    restart: always
    network_mode: host
    environment:
      - TZ=Europe/Berlin
    volumes:
      - ~/smart-home/ha_data:/config
  ccu:
    container_name: ccu
    image: occu-hmip
    volumes:
      - ~/smart-home/ccu_data:/data
    restart: always
    devices:
      - "/dev/ttyUSB0:/dev/ttyUSB0"
    ports:
      - "2010:2010"
  appdeamon:
    container_name: appdeamon
    image: appdeamon
    restart: always
    ports:
      - "5050:5050"
    environment:
      - TZ=Europe/Berlin
    volumes:
      - ~/smart-home/appdeamon_data:/config

```