# Getting started with lstack

- [Install it (Ubuntu PPA)](#install-it-ubuntu-ppa)
- [Install it cloning the git repository](#install-it-cloning-the-git-repository)
- [Use it](#use-it)


Currently Ubuntu (Precise, Trusty, Utopic) is the only Linux distribution supported.

## Install it (Ubuntu PPA)

The recommended way is to install it from the PPA:

```
$ sudo add-apt-repository ppa:rubiojr/lstack
$ sudo apt-get update
$ sudo apt-get install lstack
```

**NOTE**

If you're installing lstack on Ubuntu Precise, make sure you have LXC version 1.0.1 or greater installed in your system. See [LXC on Precise](lxc-precise.md).

## Install it cloning the git repository

Install the dependencies first:

```bash
$ sudo apt-get install qemu-kvm lxc lxc-templates git

```

You can now clone the lstack repository and run it from there:

```
$ git clone https://github.com/rubiojr/lstack
$ cd lstack && ./lstack
```

**NOTE**

If you're installing lstack on Ubuntu Precise, make sure you have LXC version 1.0.1 or greater installed in your system. See [LXC on Precise](docs/lxc-precise.md).

## Use it

You can now ssh into the container and use the OpenStack install there:

```bash
$ sudo lstack ssh
Welcome to Ubuntu 12.04.5 LTS (GNU/Linux 3.16.0-23-generic x86_64)

 * Documentation:  https://help.ubuntu.com/
root@lstack-rubiojr:~#
```

Or use the proxy commands (nova, glance, keystone, etc):

```bash
$ sudo lstack nova list --fields name,status,power_state
+--------------------------------------+------+--------+-------------+
| ID                                   | Name | Status | Power State |
+--------------------------------------+------+--------+-------------+
| fcc80833-7c47-4e01-875d-184ca6ff783b | test | ACTIVE | Running     |
+--------------------------------------+------+--------+-------------+
```

Run `lstack --help` to list the commands available.

**Next:** [how to boot a server from a QCOW2 image](/docs/deploying-ubuntu.md)
