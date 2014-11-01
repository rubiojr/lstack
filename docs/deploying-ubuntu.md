# Deploying the official QCOW2 Ubuntu Trusty image

## The quick way

1. Download the image:

    ```bash
curl https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img -o /tmp/trusty.img
```

2. Deploy it:

    ```bash
$ sudo lstack deploy --name trusty \
                     --file /tmp/trusty.img \
                     --flavor m1.tiny \
                     --volume 10
```

The deploy command is equivalent to:
* Creating the lstack container (if not created already).
* Bootstrap OpenStack Icehouse on it.
* Import the trusty image into Glance.
* Create a 10GB Cinder volume.
* Boot new server with 512MB of RAM and 1VCPU with the 10GB Cinder volume attached.

## The long way

1. Download the image:

   ```
curl https://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img -o /tmp/trusty.img
```

2. Create the lstack container:

   ```
$ sudo lstack bootstrap
```

3. Import the image into Glance:

   ```
$ sudo lstack importimg --name trusty64 /tmp/trusty.img
```

4. Create the Cinder volume and grab the volume id displayed:

   ```bash
$ sudo lstack nova volume-create --display-name tvol 10
```
That will print the volume ID among other things. You'll need it for the next step.

5. Create the server with the volume attached, replacing `<vol-id-here>` with the volume id from above:

   ```bash
$ sudo lstack nova boot --block-device source=volume,id=<vol-id-here>,dest=volume,shutdown=preserve \
			               --image trusty64 \
                           --flavor m1.tiny \
                           trusty
```

6. List the server being created:

   ```bash
$ sudo lstack nova list --fields name,status
+--------------------------------------+--------+--------+
| ID                                   | Name   | Status |
+--------------------------------------+--------+--------+
| db4108d5-c33f-4298-bb1c-23099fef325b | trusty | ACTIVE |
+--------------------------------------+--------+--------+
```
