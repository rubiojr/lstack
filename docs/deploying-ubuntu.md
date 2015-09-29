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
                     --flavor m1.tiny
```

The deploy command is equivalent to:
* Creating the lstack container (if not created already).
* Bootstrap OpenStack Juno on it.
* Import the trusty image into Glance.

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

5. Create the server:

   ```bash
$ sudo lstack nova boot --image trusty64 \
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
