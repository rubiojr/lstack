![](/images/icehouse-lxc.png)

Creates an Ubuntu Precise LXC container and installs OpenStack Icehouse on it.

```bash
git clone https://github.com/rubiojr/lxc-icehouse
./bootstrap.sh
```

Notes:

* Ubuntu Trusty and Utopic are the only hosts tested right now.
* Cinder and Neutron are not functional yet (and maybe never will? unknown.)
* `virt_type` is set to `qemu` so your benchmarks are not going to look great.
* The Icehouse is on fire.
* A fast download pipe (or an APT cache) and a speedy SSD should give you ~3 minutes of provisioning time.

All the credit goes to https://github.com/fornyx/OpenStack-Havana-Install-Guide for such an excelent guide that helped me to tame the Icehouse beast.