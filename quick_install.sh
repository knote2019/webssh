#!/bin/bash

SSH_USERNAME=${SSH_USERNAME:-root}
SSH_PASSWORD=${SSH_PASSWORD:-cloud1234}
SSH_PORT=${SSH_PORT:-5522}
WEB_SSH_PORT=${WEB_SSH_PORT:-6622}
SSH_TIMEOUT=${SSH_TIMEOUT:-30}
WS_PING_INTERVAL=${WS_PING_INTERVAL:-30}
WORKER_DELAY=${WORKER_DELAY:-10}

echo "========================================================================="
echo "WebSSH:"

apt-get update -qq
apt-get install -y openssh-server > /dev/null 2>&1 || exit 1
sed -i "s/#Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveCountMax.*/ClientAliveCountMax 3/' /etc/ssh/sshd_config
echo "$SSH_USERNAME:$SSH_PASSWORD" | chpasswd

mkdir -p /run/sshd
/usr/sbin/sshd -q
echo "SSH started (Port: $SSH_PORT)"

python setup.py install > /dev/null 2>&1 || exit 1
webssh --port="$WEB_SSH_PORT" --ssh-port="$SSH_PORT" --ssh-username="$SSH_USERNAME" --ssh-password="$SSH_PASSWORD" --timeout="$SSH_TIMEOUT" --wpintvl="$WS_PING_INTERVAL" --delay="$WORKER_DELAY" &
echo "WebSSH started (Port: $WEB_SSH_PORT)"

echo "========================================================================="
