#!/bin/bash

# --- Environment variables (set in RunPod) ---
# USER_PASS : Linux user password
# VNC_PASS  : VNC password
# TS_AUTHKEY: Tailscale auth key

cd /workspace
mkdir carla
cd /carla
wget https://carla-releases.s3.us-east-005.backblazeb2.com/Linux/CARLA_0.9.15.tar.gz \
    && tar -xvzf CARLA_0.9.15.tar.gz \
    && rm CARLA_0.9.15.tar.gz

# Setup Python environment
python3.7 -m venv carla-venv

# --- FIX: Install Python packages using the venv's pip ---
# Instead of trying to 'source activate', we call the pip executable directly.
# This ensures the packages are installed in the correct isolated environment.
source /carla-venv/bin/activate
pip install -r ./PythonAPI/examples/requirements.txt
pip install ./PythonAPI/carla/dist/carla-0.9.15-cp37-cp37m-manylinux_2_27_x86_64.whl


# --- Create user ---
useradd -m -s /bin/bash carlauser
echo "carlauser:${USER_PASS}" | chpasswd
# --- FIX: Added user to the sudo group ---
usermod -aG sudo carlauser
chown -R carlauser:carlauser /workspace

# --- Start Tailscale in the background ---
mkdir -p /workspace/tailscale
tailscaled --state=/workspace/tailscale/tailscaled.state \
           --socket=/tmp/tailscaled.sock \
           --tun=userspace-networking \
           --socks5-server=localhost:1055 \
           --outbound-http-proxy-listen=localhost:1055 &
sleep 3 # Give the daemon a moment to start

# --- Tailscale auth ---
# --- FIX: Added --ssh and --accept-routes flags ---
if [ ! -f /workspace/tailscale/authed ]; then
    tailscale up --auth-key=${TS_AUTHKEY} --hostname=carla-pod --ssh --accept-routes
    touch /workspace/tailscale/authed
else
    tailscale up --hostname=carla-pod --ssh --accept-routes
fi

# --- Run VNC and CARLA as 'carlauser' ---
echo "Starting VNC and CARLA as user 'carlauser'..."
# --- FIX: The final 'tail' command is now inside the 'su' block ---
# This ensures the user session and its background processes (like CARLA) stay alive.
su - carlauser -c '
# --- Setup VNC xstartup ---
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup <<'"'""EOF""'"'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
/usr/bin/startxfce4
EOF

chmod +x ~/.vnc/xstartup
(echo "${VNC_PASS}"; echo "${VNC_PASS}") | vncpasswd

# --- Start VNC server ---
vncserver :1 -geometry 1280x800 -depth 24 -localhost no

# --- FIX: Added a sleep to ensure the display is ready ---
sleep 5

# --- Set environment for CARLA ---
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/carlauser-runtime
mkdir -p $XDG_RUNTIME_DIR && chmod 700 $XDG_RUNTIME_DIR

# --- Activate Python venv and start CARLA in the background ---
source /workspace/carla-venv/bin/activate
/workspace/carla/CarlaUE4.sh -opengl &

echo "Setup complete. Container is running."
# --- Keep the user session alive ---
tail -f /dev/null
'
