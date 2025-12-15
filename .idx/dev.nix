{ pkgs, ... }: {
  channel = "stable-24.11";

  packages = [
    pkgs.docker
    pkgs.socat
    pkgs.cloudflared
    pkgs.coreutils
    pkgs.gnugrep
  ];

  services.docker.enable = true;

  idx.workspace.onStart = {
    novnc = ''
      set -e
      cd /home/user || true

      # ===============================
      # Build image once
      # ===============================
      if ! docker images | grep -q ubuntu-novnc-24; then
        docker build -t ubuntu-novnc-24 .
      fi

      # ===============================
      # Run container
      # ===============================
      if ! docker ps -a --format '{{.Names}}' | grep -qx ubuntu-novnc; then
        docker run --name ubuntu-novnc \
          --shm-size 1g \
          --cap-add=SYS_ADMIN \
          -d \
          -p 8080:10000 \
          ubuntu-novnc-24
      else
        docker start ubuntu-novnc || true
      fi

      # ===============================
      # Cloudflare Tunnel
      # ===============================
      nohup cloudflared tunnel \
        --no-autoupdate \
        --url http://localhost:8080 \
        > /tmp/cloudflared.log 2>&1 &

      sleep 8
      grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1 || true

      # ===============================
      # Keep workspace alive
      # ===============================
      while true; do sleep 60; done
    '';
  };

  idx.previews = {
    enable = true;
    previews = {
      novnc = {
        manager = "web";
        command = [
          "bash" "-lc"
          "socat TCP-LISTEN:9000,fork,reuseaddr TCP:127.0.0.1:8080"
        ];
      };
    };
  };
}
