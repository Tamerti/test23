FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=user
ENV HOME=/home/user
ENV DISPLAY=:1
ENV VNC_PORT=5900
ENV NOVNC_PORT=10000
ENV SCREEN_WIDTH=1280
ENV SCREEN_HEIGHT=800
ENV SCREEN_DEPTH=24

# ===============================
# Base system
# ===============================
RUN apt update && apt install -y \
    sudo wget curl ca-certificates \
    dbus-x11 x11-xserver-utils \
    xfce4 xfce4-goodies \
    tightvncserver \
    novnc websockify \
    pulseaudio pavucontrol \
    fonts-dejavu fonts-freefont-ttf \
    unzip \
    && apt clean && rm -rf /var/lib/apt/lists/*

# ===============================
# User
# ===============================
RUN useradd -m ${USER} \
    && echo "${USER}:${USER}" | chpasswd \
    && usermod -aG sudo ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ===============================
# Google Chrome
# ===============================
RUN wget -q -O /tmp/chrome.deb \
      https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt update \
    && apt install -y /tmp/chrome.deb \
    && rm -f /tmp/chrome.deb \
    && apt clean && rm -rf /var/lib/apt/lists/*

# ===============================
# noVNC
# ===============================
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

USER ${USER}
WORKDIR ${HOME}

# ===============================
# VNC password: 12345678
# ===============================
RUN mkdir -p ~/.vnc \
    && echo "12345678" | vncpasswd -f > ~/.vnc/passwd \
    && chmod 600 ~/.vnc/passwd

# ===============================
# XFCE startup
# ===============================
RUN printf '#!/bin/sh\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
exec startxfce4 &\n' > ~/.vnc/xstartup \
    && chmod +x ~/.vnc/xstartup

# ===============================
# Start script
# ===============================
RUN printf '#!/bin/bash\n\
set -e\n\
pulseaudio --start || true\n\
vncserver :1 -geometry ${SCREEN_WIDTH}x${SCREEN_HEIGHT} -depth ${SCREEN_DEPTH}\n\
websockify --web /usr/share/novnc/ ${NOVNC_PORT} localhost:${VNC_PORT}\n\
' > ${HOME}/start.sh \
    && chmod +x ${HOME}/start.sh

EXPOSE 5900 10000

CMD ["bash", "/home/user/start.sh"]
