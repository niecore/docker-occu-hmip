FROM debian:buster-slim

# Install required packages
RUN mkdir -p /usr/share/man/man1 \
    && apt-get update && apt-get install -y --no-install-recommends \
    openjdk-11-jre-headless \
    curl \
    lighttpd \
    && rm -rf /var/lib/apt/lists/*

ARG OCCU_VERSION=3.47.10
ARG HMIP_RFUSB_VERSION=2.8.6

# Install OCCU / HMIP daemon
WORKDIR /usr/src
RUN curl -SLk https://github.com/eq-3/occu/archive/${OCCU_VERSION}.tar.gz | tar xzf - \
    && cd occu-${OCCU_VERSION} \
    && mkdir -p /opt/hm \
    && mkdir -p /etc/config/firmware \
    && cp -r firmware / \
    && cp -r HMserver/* / \
    && rm -rf /usr/src/occu-${OCCU_VERSION} \
    && echo "VERSION=${OCCU_VERSION}" > /VERSION \
    && mv /firmware/HmIP-RFUSB/hmip_coprocessor_update.eq3 /firmware/HmIP-RFUSB/hmip_coprocessor_update_${HMIP_RFUSB_VERSION}.eq3 \
    && ln -s /opt/hm/etc/config /etc/config 

# Set required environment variables
ENV HM_HOME=/opt/hm LD_LIBRARY_PATH=/opt/hm/lib:${LD_LIBRARY_PATH}

# Update config files
COPY data/crRFD.conf data/log4j.xml data/InterfacesList.xml /etc/config/

# Copy scripts
COPY data/run.sh /

WORKDIR /data
CMD [ "/run.sh" ]

EXPOSE 2010