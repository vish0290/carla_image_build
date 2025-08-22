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

# Download and extract CARLA 0.9.15
WORKDIR /opt
RUN mkdir carla
WORKDIR /opt/carla
RUN wget https://carla-releases.s3.us-east-005.backblazeb2.com/Linux/CARLA_0.9.15.tar.gz \
    && tar -xvzf CARLA_0.9.15.tar.gz \
    && rm CARLA_0.9.15.tar.gz

# Setup Python environment
WORKDIR /opt/carla/PythonAPI
RUN python3.7 -m venv /opt/carla-venv

# --- FIX: Install Python packages using the venv's pip ---
# Instead of trying to 'source activate', we call the pip executable directly.
# This ensures the packages are installed in the correct isolated environment.
RUN /opt/carla-venv/bin/pip install --upgrade pip
RUN /opt/carla-venv/bin/pip install -r /opt/carla/PythonAPI/examples/requirements.txt
RUN /opt/carla-venv/bin/pip install /opt/carla/PythonAPI/carla/dist/carla-0.9.15-cp37-cp37m-manylinux_2_27_x86_64.whl

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose VNC port
EXPOSE 5901

CMD ["/entrypoint.sh"]