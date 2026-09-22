#!/bin/bash
# FAIL ON ERROR & ENABLE SUCCESS MONITORING

set -ex
exec > >(tee -a /var/log/startup-script.log | logger -t startup-script -s 2>/dev/console) 2>&1

echo "[*] Starting Exposed Honeypot setup..."

# Block GCP Metadata
iptables -A OUTPUT -d 169.254.169.254 -j DROP
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
netfilter-persistent save

apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y git python3 python3-pip python3-venv libssl-dev libffi-dev build-essential libpython3-dev python3-minimal authbind acl gnupg apt-transport-https

# Create user and set up authbind files as root
adduser --disabled-password --gecos "" cowrie
touch /etc/authbind/byport/22 /etc/authbind/byport/23
chown cowrie:cowrie /etc/authbind/byport/22 /etc/authbind/byport/23
chmod 770 /etc/authbind/byport/22 /etc/authbind/byport/23

# Execute commands safely as the honeypot user
sudo -i -u cowrie bash << 'EOF'
set -e
mkdir ~/my-honeypot && cd ~/my-honeypot
python3 -m venv cowrie-env
source cowrie-env/bin/activate
pip install cowrie
cowrie init

sed -i 's/hostname = svr04/hostname = web-gateway-03/' etc/cowrie.cfg
sed -i 's/#fake_addr = 192.168.66.254/fake_addr = 192.168.0.94/' etc/cowrie.cfg
sed -i 's/listen_endpoints = tcp:2222:interface=0.0.0.0/listen_endpoints = tcp:22:interface=0.0.0.0/' etc/cowrie.cfg
sed -i 's/listen_endpoints = tcp:2223:interface=0.0.0.0/listen_endpoints = tcp:23:interface=0.0.0.0/' etc/cowrie.cfg
sed -i '/^\[telnet\]/,/^\[/ s/.*enabled =.*/enabled = true/' etc/cowrie.cfg
EOF

# Disable native SSH server
systemctl stop sshd 
systemctl disable sshd 
apt-get purge -y openssh-server

# Start the honeypot
sudo -i -u cowrie bash -c "cd ~/my-honeypot && source cowrie-env/bin/activate && AUTHBIND_ENABLED=yes cowrie start"

# Wazuh Agent Installation
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
apt-get update

WAZUH_MANAGER="10.10.10.2" DEBIAN_FRONTEND=noninteractive apt-get install wazuh-agent -y
systemctl daemon-reload
systemctl enable wazuh-agent

# Configure Wazuh localfile settings
sed -i '0,/<\/localfile>/s|.*<\/localfile>.*|&\n\n  <localfile>\n    <location>/home/cowrie/my-honeypot/var/log/cowrie/cowrie.json</location>\n    <log_format>json</log_format>\n  </localfile>|' /var/ossec/etc/ossec.conf
sed -i '/<location>\/home\/cowrie\/my-honeypot\/var\/log\/cowrie\/cowrie\.json<\/location>/,/<\/localfile>/ s/<\/localfile>/  <only-future-events>no<\/only-future-events>\n<\/localfile>/' /var/ossec/etc/ossec.conf

# Set ACLs for Wazuh log access
setfacl -m u:wazuh:rx /home/cowrie
setfacl -m u:wazuh:rx /home/cowrie/my-honeypot
setfacl -m u:wazuh:rx /home/cowrie/my-honeypot/var
setfacl -m u:wazuh:rx /home/cowrie/my-honeypot/var/log
setfacl -m u:wazuh:rx /home/cowrie/my-honeypot/var/log/cowrie
setfacl -m u:wazuh:r /home/cowrie/my-honeypot/var/log/cowrie/cowrie.json

systemctl start wazuh-agent
systemctl restart wazuh-agent
sed -i "s/^deb /#deb/" /etc/apt/sources.list.d/wazuh.list
apt-get update

# Suricata Installation
DEBIAN_FRONTEND=noninteractive apt-get install -y suricata 
suricata-update
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
sed -i "s/interface: eth0/interface: $INTERFACE/g" /etc/suricata/suricata.yaml
sed -i '0,/<\/localfile>/s|.*<\/localfile>.*|&\n\n  <localfile>\n    <location>/var/log/suricata/eve.json</location>\n    <log_format>json</log_format>\n  </localfile>|' /var/ossec/etc/ossec.conf
systemctl restart suricata
systemctl restart wazuh-agent

# --- PHASE 4 OPSEC LOG CLEANUP ---
echo "[*] Clearing all installation logs..."
cat /dev/null > /var/log/auth.log
cat /dev/null > /var/log/syslog
history -c
rm -f /root/.bash_history
rm -f /home/cowrie/.bash_history

echo "[*] Exposed setup completed successfully!"