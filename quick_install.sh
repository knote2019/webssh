#!/bin/bash

SSH_USERNAME=${SSH_USERNAME:-root}
SSH_PASSWORD=${SSH_PASSWORD:-cloud1234}
SSH_PORT=${SSH_PORT:-5522}
WEB_SSH_PORT=${WEB_SSH_PORT:-6622}

echo "========================================================================="
echo "WebSSH:"

apt-get update -qq
apt-get install -y openssh-server > /dev/null 2>&1 || exit 1
sed -i "s/#Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveInterval.*/ClientAliveInterval 0/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveCountMax.*/ClientAliveCountMax 0/' /etc/ssh/sshd_config
echo "$SSH_USERNAME:$SSH_PASSWORD" | chpasswd

mkdir -p /run/sshd
/usr/sbin/sshd -q
echo "SSH started (Port: $SSH_PORT)"

python setup.py install > /dev/null 2>&1 || exit 1
webssh --port="$WEB_SSH_PORT" --ssh-port="$SSH_PORT" --ssh-username="$SSH_USERNAME" --ssh-password="$SSH_PASSWORD" &
echo "WebSSH started (Port: $WEB_SSH_PORT)"

echo "========================================================================="
