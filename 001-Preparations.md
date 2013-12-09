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

# Cache Ubuntu 12.04 64bit Box

As you might use the very same virtual machine for all your clients and servers
it is useful to have the Vagrant box on your local disk.

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
