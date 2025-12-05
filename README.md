### webssh.

    +---------+     http     +----------------------+
    | browser | <==========> | webssh <=> ssh server|
    +---------+   websocket  +----------------------+

### install.

step1: install ssh server:

    apt-get install -y openssh-server
    sed -i 's/#Port.*/Port 5522/' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveInterval.*/ClientAliveInterval 0/' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveCountMax.*/ClientAliveCountMax 0/' /etc/ssh/sshd_config
    echo 'root:cloud1234' | chpasswd
    mkdir -p /run/sshd
    /usr/sbin/sshd -q

step2: install webssh server:

    git clone https://github.com/knote2019/webssh.git
    cd webssh
    python setup.py install
    webssh --port=6622 --ssh-port=5522 --ssh-username=root --ssh-password=cloud1234

### login.
    http://10.118.5.99:6622
