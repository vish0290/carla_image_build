# Base image with CUDA
FROM nvidia/cuda:12.2.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
# Add the virtual environment's bin to the PATH. This is a good practice.
ENV PATH="/opt/carla-venv/bin:$PATH"

RUN apt-get update && apt-get install -y software-properties-common && \
    # Add the deadsnakes PPA which contains older python versions
    add-apt-repository ppa:deadsnakes/ppa

# Install system packages - This was already perfect.
RUN apt-get update && apt-get install -y \
    sudo wget curl git unzip gnupg lsb-release \
    python3.7 python3-pip python3.7-venv python3.7-dev \
    xfce4 xfce4-goodies tigervnc-standalone-server \
    x11vnc xvfb xterm dbus-x11 xdg-user-dirs \
    && rm -rf /var/lib/apt/lists/*

# Install Tailscale
RUN curl -fsSL https://tailscale.com/install.sh | sh

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose VNC port
EXPOSE 5901

CMD ["/entrypoint.sh"]