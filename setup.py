from setuptools import setup
from webssh._version import __version__ as version


setup(
    name='webssh',
    version=version,
    description='webssh',
    author='kenny',
    url='https://github.com/knote2019/webssh',
    packages=['webssh'],
    entry_points='''
    [console_scripts]
    webssh = webssh.main:main
    ''',
    license='MIT',
    include_package_data=True,
    install_requires=['paramiko>=2.3.1', 'tornado>=4.5.0'],
)
