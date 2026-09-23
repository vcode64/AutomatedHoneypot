#!/bin/bash

# FAIL ON ERROR & ENABLE SUCCESS MONITORING
set -ex
exec > >(tee -a /var/log/startup-script.log | logger -t startup-script -s 2>/dev/console) 2>&1

echo "[*] Starting Monitor setup..."

apt update && apt upgrade -y

curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && bash ./wazuh-install.sh -a
sed -i "s/^deb /#deb /" /etc/apt/sources.list.d/wazuh.list
apt update

cat << 'EOF' >> /var/ossec/etc/rules/local_rules.xml
<group name="cowrie,honeypot,">
  <!-- Base Rule: Catch all Cowrie JSON logs -->
  <rule id="100010" level="3">
    <decoded_as>json</decoded_as>
    <field name="eventid">^cowrie.</field>
    <description>Cowrie Honeypot: $(eventid)</description>
  </rule>
  <!-- Connection Phase -->
  <rule id="100011" level="4">
    <if_sid>100010</if_sid>
    <field name="eventid">^cowrie.session.connect$</field>
    <description>Cowrie: New connection established from $(src_ip)</description>
  </rule>
  <rule id="100012" level="4">
    <if_sid>100010</if_sid>
    <field name="eventid">^cowrie.session.closed$</field>
    <description>Cowrie: Connection closed by $(src_ip)</description>
  </rule>
  <!-- Authentication Phase -->
  <rule id="100013" level="5">
    <if_sid>100010</if_sid>
    <field name="eventid">^cowrie.login.failed$</field>
    <description>Cowrie: Failed login attempt for $(username) using password '$(password)' from $(src_ip)</description>
    <group>authentication_failed,</group>
  </rule>
  <rule id="100014" level="10">
    <if_sid>100010</if_sid>
    <field name="eventid">^cowrie.login.success$</field>
    <description>Cowrie: Successful login for $(username) using password '$(password)' from $(src_ip)</description>
    <group>authentication_success,attack,</group>
  </rule>
  <!-- Execution Phase -->
  <rule id="100015" level="8">
    <if_sid>100010</if_sid>
    <field name="eventid">^cowrie.command.input$</field>
    <description>Cowrie: Attacker $(src_ip) executed command: $(input)</description>
    <group>attack,</group>
  </rule>
  <!-- Payload Delivery Phase -->
  <rule id="100016" level="12">
    <if_sid>100010</if_sid>
    <field name="eventid">^cowrie.session.file_download$</field>
    <description>Cowrie: Attacker $(src_ip) downloaded malware payload from $(url)</description>
    <group>attack,malware,</group>
  </rule>
  <rule id="100017" level="12">
    <if_sid>100010</if_sid>
    <field name="eventid">^cowrie.session.file_upload$</field>
    <description>Cowrie: Attacker $(src_ip) uploaded file $(filename)</description>
    <group>attack,malware,</group>
  </rule>
  <!-- Composite Rule: Brute Force Burst Detection -->
  <rule id="100018" level="10" frequency="8" timeframe="60">
    <if_matched_sid>100013</if_matched_sid>
    <same_field>src_ip</same_field>
    <description>Cowrie: SSH Brute Force burst detected from $(src_ip)</description>
    <group>authentication_failed,attack,</group>
  </rule>
</group>
EOF

# Show all logs, instead of alerts only:
sed -i 's#<logall>no</logall>#<logall>yes</logall>#' /var/ossec/etc/ossec.conf
sed -i 's#<logall_json>no</logall_json>#<logall_json>yes</logall_json>#' /var/ossec/etc/ossec.conf
sed -i '/^[[:space:]]*archives:/,+1 s/\(enabled:[[:space:]]*\)false/\1true/' /etc/filebeat/filebeat.yml

systemctl restart wazuh-manager
systemctl restart filebeat

echo "[*] Monitor setup completed successfully!"