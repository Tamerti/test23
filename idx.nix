{ pkgs, ... }: {
  channel = "stable-24.11";

  packages = [
    pkgs.docker
    pkgs.cloudflared
    pkgs.socat
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.sudo
    pkgs.unzip
  ];

  services.docker.enable = true;

  idx.workspace.onStart = {
    novnc = ''
      set -e

      # =========================================
      # One-time cleanup
      # =========================================
      if [ ! -f /home/user/.cleanup_done ]; then
        rm -rf /home/user/.gradle/* /home/user/.emu/*
        find /home/user -mindepth 1 -maxdepth 1 \
          ! -name 'idx-ubuntu22-gui' ! -name '.*' \
          -exec rm -rf {} +
        touch /home/user/.cleanup_done
      fi

      # =========================================
      # Create / Start Ubuntu 24.04 noVNC container
      # =========================================
      if ! docker ps -a --format '{{.Names}}' | grep -qx 'ubuntu-novnc'; then
        docker run --name ubuntu-novnc \
          --shm-size 1g \
          --cap-add=SYS_ADMIN \
          -d \
          -p 8080:10000 \
          -e VNC_PASSWD=12345678 \
          -e PORT=10000 \
          -e AUDIO_PORT=1699 \
          -e WEBSOCKIFY_PORT=6900 \
          -e VNC_PORT=5900 \
          -e SCREEN_WIDTH=1024 \
          -e SCREEN_HEIGHT=768 \
          -e SCREEN_DEPTH=24 \
          thuonghai2711/ubuntu-novnc-pulseaudio:24.04
      else
        docker start ubuntu-novnc || true
      fi

      # =========================================
      # Install Google Chrome (only if missing)
      # =========================================
      docker exec ubuntu-novnc bash -lc "
        if ! command -v google-chrome >/dev/null 2>&1; then
          sudo apt update &&
          sudo apt remove -y firefox || true &&
          sudo apt install -y wget &&
          wget -O /tmp/chrome.deb \
            https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb &&
          sudo apt install -y /tmp/chrome.deb &&
          rm -f /tmp/chrome.deb
        fi
      "

      # =========================================
      # Start Cloudflared tunnel
      # =========================================
      nohup cloudflared tunnel \
        --no-autoupdate \
        --url http://localhost:8080 \
        > /tmp/cloudflared.log 2>&1 &

      sleep 10

      # =========================================
      # Print Cloudflare URL
      # =========================================
      if grep -q "trycloudflare.com" /tmp/cloudflared.log; then
        URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1)
        echo "========================================="
        echo " 🌍 Cloudflared tunnel ready:"
        echo "     $URL"
        echo "========================================="
      else
        echo "❌ Cloudflared failed, check /tmp/cloudflared.log"
      fi

      # =========================================
      # Keep workspace alive
      # =========================================
      elapsed=0
      while true; do
        echo "⏱️  Time elapsed: $elapsed min"
        ((elapsed++))
        sleep 60
      done
    '';
  };

  idx.previews = {
    enable = true;
    previews = {
      novnc = {
        manager = "web";
        command = [
          "bash" "-lc"
          "socat TCP-LISTEN:$PORT,fork,reuseaddr TCP:127.0.0.1:8080"
        ];
      };
    };
  };
}
