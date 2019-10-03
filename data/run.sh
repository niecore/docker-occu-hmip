#!/bin/bash

# Initialise data folder
mkdir -p /share/hmip-firmware
mkdir -p /data/crRFD

function updateHmIPFirmware() {

    local UPDATE_FILE="$(ls /firmware/HmIP-RFUSB/hmip_coprocessor_update_*.eq3)"

    if [ ! -f /data/firmware_updated ]; then
        java -Xmx64m -jar /opt/HmIP/hmip-copro-update.jar -p /dev/ttyUSB0 -f "${UPDATE_FILE}"
        touch /data/firmware_updated
    else
        echo "[INFO] HmIP firmware already up to date."
    fi
}

# Restore recent device metadata
if [ -f /data/hmip_address.conf ]; then
    cp -f /data/hmip_address.conf /etc/config/
fi

# Update Firmware
updateHmIPFirmware 

# Run HMIPServer
java -Xmx64m -Dlog4j.configuration=file:///etc/config/log4j.xml -jar /opt/HMServer/HMIPServer.jar /etc/config/crRFD.conf &
CCU_PID=$!

# Backup device metadata
if [ ! -f /data/hmip_address.conf ]; then
    sleep 30
    cp -f /etc/config/hmip_address.conf /data/
fi

# Keep container running while CCU is alive
wait ${CCU_PID}