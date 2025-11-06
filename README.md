### webssh.

    +---------+     http     +----------------------+
    | browser | <==========> | webssh <=> ssh server|
    +---------+   websocket  +----------------------+

### install.

    python setup.py install
    wssh --port=6622 --ssh-port=22 --ssh-username=<SSH-USERNAME> --ssh-password=<SSH-PASSWORD>

### login.
    http://10.176.196.66:6622
