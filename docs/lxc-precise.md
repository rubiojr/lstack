# LXC on Ubuntu Precise

The LXC version that comes with Precise is not supported by lstack. To install a newer version follow these steps:

1. A add the ubuntu-lxc/stable ppa

   ```
$ sudo apt-get install python-software-properties
$ sudo add-apt-repository ppa:ubuntu-lxc/stable
```

2. Install the lxc package

   ```
$ sudo apt-get update
$ sudo apt-get install lxc
```

That should install LXC version `1.0.6` or greater that is supported by lstack.

If you're installing `lxc >= 1.1` make sure you also install the `lxc-templates` package.
