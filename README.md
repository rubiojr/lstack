![](/images/icehouse-lxc.png)

Create OpenStack LXC containers.

```bash
git clone https://github.com/rubiojr/lstack
./lstack.sh bootstrap
```

## Description

Creates an LXC container and installs OpenStack Icehouse from the Ubuntu Cloud Archive. Services currently supported:

* Nova Compute (kvm)
* Cinder (using BlockDeviceDriver)
* Keystone
* Nova Network (flat topology)
* Glance

## Usage


lstack has a built-in help:

```
$ ./lstack.sh --help
Usage: lstack [options] [command]

OPTIONS

--help                Print help
--version             Print version

COMMANDS

bootstrap             Bootstrap the OpenStack container
info                  Print container info (lxc-info)
ssh                   SSH into the container
nova                  Run the nova command inside the container
destroy               Destroy the container
```

To destroy the container:

```
$ ./lstack.sh destroy
** Destroying the container...
```

To SSH to the container:

```
$ ./lstack.ssh ssh
```

## Notes

* Ubuntu Trusty and Utopic are the only hosts tested right now.
* Neutron is not supported right now. I'm using a flat network with nova-network.
* Provisioning time usually takes between 3 and 10 minutes. A fast download pipe (or an APT cache) and a speedy SSD should do it in ~3 minutes.
* Cinder is configured to use BlockDeviceDriver. More on this later.

## Credits

* https://github.com/fornyx/OpenStack-Havana-Install-Guide for such an excelent guide that helped me to tame the Icehouse beast.
