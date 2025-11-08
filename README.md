### webssh.

    +---------+     http     +----------------------+
    | browser | <==========> | webssh <=> ssh server|
    +---------+   websocket  +----------------------+

### install.

    python setup.py install
    webssh --port=6622 --ssh-port=5522 --ssh-username=<SSH-USERNAME> --ssh-password=<SSH-PASSWORD>

### login.
    http://127.0.0.1:6622
