# Preface

Chef as an Configuration Management Framework seems to be an overkill for small sized projects at first glance.
This is definitely true if we consider only projects as easy to install as nodejs apps.
However, production level applications with databases etc. need even then some effort which we have been addressing
using scripts or manually.

I see some immediate benefits for us using such a technology.
The installation of a single server gets managed and documented, and becomes reproducible and shareable.
Adopting virtualization opens the opportunity to roll out deployments on staging machines first. We do not need extra hardware for that - everybody can do that locally. The best of all - everybody can.
Being able to emulate multi-node infrastructure, we can play with scaling and backup strategies.


# Vagrant

If you don't know *Vagrant*: it's all about creating Virtual Machines (VirtualBox, VMWare, etc.) from the command line.
See http://www.vagrantup.com.


Download the installer for your system from http://downloads.vagrantup.com.
When writing this tutorial it was of version `1.3.5`.

    Note: to install the `.deb` file under Ubuntu you can run `sudo dpkg -i <package>.deb`

## Snapshot plugin

This plugin is very useful to create certain recovery points. So you don't need to create a virtual machine from scratch
everytime when you just want to reset it. See https://github.com/dergachev/vagrant-vbox-snapshot.

```
$ vagrant plugin install vagrant-vbox-snapshot
```

## Caching

As we will use one common base image for all client and server virtual machines
it is useful to fetch that Vagrant box onto your local disk.

```
$ vagrant box add precise64 http://opscode-vm-bento.s3.amazonaws.com/vagrant/virtualbox/opscode_ubuntu-12.04_chef-provisionerless.box
```

# Chef Server

In the `server` folder you find a vagrant configuration that creates a server running on `192.168.50.100`.

```
/ $ cd server
/server $ vagrant up
```

After this has finished you have a bare Chef (OpenSource) Server running.
I prefer to add an alias to my `/etc/hosts`:

```
192.168.50.100 chefserver.substance.io chefserver
```

You should then be able to `ping` your server:

```
/server $ ping chefserver.substance.io
PING chefserver.substance.io (192.168.50.100) 56(84) bytes of data.
64 bytes from chefserver.substance.io (192.168.50.100): icmp_req=1 ttl=64 time=0.830 ms
64 bytes from chefserver.substance.io (192.168.50.100): icmp_req=2 ttl=64 time=0.573 ms
```

## Librarian

A useful tool to manage external/community cookbooks:

```
$ sudo gem install librarian-chef
```

You will see later how this is used.


    Note: Unfortunately, the librarian requires Ruby >= 1.9.2 which is not installed on OSX by default
    (at least on Mountain Lion). There are several options to get Ruby 1.9.3.
    For me the easiest way was usìng `rvm` which is bundled in `RailsInstaller` (full Rails toolchain),
    or can be brewn with `homebrew`.

```
$ rvm install 1.9.3
```

## Keys for Server Administration and Client Registration

    TODO: maybe I could add some screenshots

Open your web-browser and navigate to the URL `https://chefserver.substance.io`.

Login as user `admin` using password `p@ssw0rd1`.

Enable the checkbox `Regenerate Private Key` and change the admin password.
Store the private key as `.chef/admin.pem`.

Open `Clients` tab and `Edit` the client `chef-validator`.
Enable the checkbox `Private Key` and `Save Client`.
Store the private key as `.chef/chef-validator.pem`

## Snapshot

At this point it makes sense to create a snapshot of the server.

```
/server $ vagrant snapshot take vanilla
```

You can then return to that version using:

```
/server $ vagrant snapshot go vanilla
```

# Summary

Now you should have...

- a Chef Server running on https://192.168.50.100 (check in web-browser)

- an alias `chefserver.substance.io` resolving to that local ip.

- a snapshot of the current server image

```
/server $ vagrant snapshot list
Listing snapshots for 'default':
   Name: vanilla (UUID: 892bb7b3-8463-4f44-a008-960c2e1bbb1e) *
```

- private keys for Chef `admin` and `chef-validator`

```
$ ls chef-repo/.chef/
admin.pem   chef-validator.pem  knife.rb
```

- librarian-chef installed

```
$ librarian-chef version
librarian-0.1.1
librarian-chef-0.0.2
```
