![](/docs/images/icehouse-lxc.png)

Create OpenStack LXC containers.

**lstack is currently in beta**

See the [GETTING STARTED](/docs/getting-started.md) guide.

## Description

Creates an LXC container and installs OpenStack Juno from the Ubuntu Cloud Archive. Services currently supported:

* Nova Compute (kvm)
* Keystone
* Nova Network (flat topology)
* Glance
* Swift

## Usage

lstack has a built-in help:

```bash
Usage: lstack [options] [command]

OPTIONS

--help                Print help
--version             Print version
--nocolor             No colors for the output
--quiet               Do not print info and warning messages
--nonyancat           Nooooooo!

COMMANDS

bootstrap             Bootstrap the OpenStack container
info                  Print container info (lxc-info)
ssh                   SSH into the container
nova                  Run the nova command inside the container
destroy               Destroy the container
ip                    Print the IP of the container
importimg             Import a QCOW2 image to Glance
deploy                Create an instance from a QCOW2 image
forward               Forward ports to a running intsance
glance                Run the glance command inside the container
keystone              Run the keystone command inside the container
cinder                Run the cinder command inside the container
```

To destroy the container:

```bash
$ sudo lstack destroy
** Destroying the container...
```

To SSH to the container:

```bash
$ sudo lstack ssh
```

To create an instance from a QCOW2 image:

```bash
$ sudo lstack deploy --file /path/to/image.qcow2 --name test --flavor m1.tiny
```

To run Nova commands inside the container use the nova command:

```bash
$ sudo lstack nova flavor-list
```

To forward container ports to a running instance:

```bash
$ sudo lstack forward test 22 443
```

TCP connections to the ports 22 and 443 of container will be forwarded to the 'test' instance ports 22 and 443.

## Notes

* Neutron is not supported right now. I'm using a flat network with nova-network.
* Provisioning time usually takes between 3 and 10 minutes. A fast download pipe (or an APT cache) and a speedy SSD should do it in ~3 minutes.
* Cinder is installed but not working currently.

## Future plans

* OpenStack Juno support using Ubuntu Trusty containers.
* Adding OpenStack Swift.
* Volume support for instances (no longer working after Juno).
* Maybe Neutron replacing legacy Nova network if that's possible at all.

See the [TODO](TODO.md) list.

## Credits

* https://github.com/fornyx/OpenStack-Havana-Install-Guide for such an excelent guide that helped me to tame the Icehouse beast.
* [The Awesome Shell repo](https://github.com/alebcay/awesome-shell).
* The great [dispatch](https://github.com/Mosai/workshop/blob/master/doc/dispatch.md) implementation.
