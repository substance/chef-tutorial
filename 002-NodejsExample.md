# Client Machine

You find everything prepared in `./nodejs-example`.

```
$ cd nodejs-example
nodejs-example $ vagrant up
```

After that you should have a client running on `192.168.50.10`
If you want you can create an alias in `/etc/hosts`

```
192.168.50.10 example1.substance.io example1
```

    > Note: this vagrant is configured to register itself to the server.
    > For that to work the server must be running.

## Snapshot

If you want, now is a good moment to take a snapshot.

```
chef-repo $ cd ../nodejs-example
nodejs-example $ vagrant snapshot take vanilla
```

# Chef Basics

With Chef every configurational aspect is expressed in so called cookbooks.
There are a lot of open community cookbooks available for very many different things.
Specifying the configuration for one single application very often takes only one integrational cookbook
which pulls in external cookbooks.

We use `librarian-chef` to manage external cookbooks which is configured by a `Cheffile` you find in the `chef-repo`.

`chef-repo/Cheffile`:

```
site 'http://community.opscode.com/api/v1'

cookbook 'apt'
cookbook 'omnibus_updater'
```

## Run the librarian

```
chef-repo $ librarian-chef install
```

After that you find the two cookbooks in `chef-repo/cookbooks`.
A place to look for a general description is the `README.md` in each cookbook - very often there is an Example section.
The other most interesting places are: `metadata.rb` with cookbook information (version, dependencies, etc),
`attributes/default.rb` with all of the cookbook's parameters, `recipes/*.rb` with the different run-modes,
and `resources/*.rb` with the specification of the 'structures' provided by the cookbook.

We use the cookbooks 'apt' and 'omnibus_updater' in their default configuration, i.e., we do not need to specify any
attributes.

## Upload cookbooks

At the moment all cookbooks are stored only locally and need to be transferred to the server.

```
chef-repo $ knife cookbook upload --all
```

## Edit Run List

Each node has a specific run-list that determines which cookbooks or more precisely which recipes are
executed and used for managing the state of the client machine.

To edit this list:

```
chef-repo $ knife node edit example1
```

This will open up `nano` to edit a json file.

```
{
  "name": "example1",
  "chef_environment": "_default",
  "normal": {
    "tags": [
    ]
  },
  "run_list": [
  ]
}
```

Change `run_list` and save.

```
  "run_list": [
    "recipe[apt]",
    "recipe[omnibus_updater]"
  ]
```

    Note: you can change the built-in editor in `chef-repo/.chef/knife.rb` setting the property `knife[:editor]`

## Update client

After a change to a cookbook or node properties (e.g., a run list) the client
needs to be updated to have an effect.

There are two ways to update the client machine: calling `chef-client` on the machine
or using the installed vagrant provisioning mechanism.

```
nodejs-example $ vagrant ssh
[example1] ~ $ sudo chef-client
```

or:

```
nodejs-example $ vagrant provision
```

After that you should see `chef-client` installing the cookbooks and updating `apt`.


# NodeJS Example

Let's take a look at a first example for NodeJS: a simple HelloWorld express application.

`app.js`:

```
var express = require('express');

var app = express();

app.get('/', function(req, res){
  res.send('Hello World');
});

app.listen(5000);
console.log('Express started on port 5000');
```

`package.json`:

```
{
  "name": "hello_world",
  "private": true,
  "version": "0.0.1",
  "description": "NodeJS Hello World Express Server.",
  "dependencies": {
    "express": "*"
  }
}
```

    Note: the application source code is kept in its own repository: https://github.com/oliver----/nodejs_helloworld.


## More cookbooks

For this configuration task there is a community cookbook available [application_nodejs](https://github.com/conradev/application_nodejs). So we add this to the list of external cookbooks.

Add this to `chef-repo/Cheffile`:

```
cookbook 'application', '3.0.0'
cookbook 'application_nodejs',
  :git => 'https://github.com/conradev/application_nodejs',
  :ref => '2.0.0'
```

>  Note: A first problem occurred here, 'application_nodejs' can not be used without specifying the repository.
>        Another problem was, the latest version of cookbook `application` (>= 4.0.0) seems incompatible with
>        `application_nodejs`, so we need to stick to version 3.0.0.
>        See Troubleshooting below.

## Custom Cookbook

Create a new cookbook using

```
chef-repo $ knife cookbook create example1 -o site-cookbooks
```

As we use `librarian` personal cookbooks and external ones are kept in different folders.
Thus we have to specify the option `-o site-cookbooks`

### Edit the Recipe

Open `chef-repo/site-cookbooks/example1/recipes/default.rb` and add the following block:

```
application "hello-world" do
  path "/var/www/nodejs/hello-world"
  owner "www-data"
  group "www-data"
  packages ["git"]
  repository "https://github.com/oliver----/nodejs_helloworld.git"
  nodejs do
    entry_point "app.js"
  end
end
```

`application` is a resource provided by the `application` cookbook (see `cookbooks/application/resource/default.rb`).
Basically, this resource takes care of installing the source code and trigger actions whenever the repository
has been changed.
`nodejs` is a sub-resource provided by the cookbook `application_nodejs`. It installs nodejs and registers the
application with `upstart`.

### Extend the Run List

Add the cookbook to the nodes run-list:

```
chef-repos/ $ knife node edit example1
```

```
  ...
  "run_list": [
    "recipe[apt]",
    "recipe[omnibus_updater]",
    "recipe[example1]"
  ]
  ...
```

### Update the client:

```
nodejs-example/ $ vagrant provision
```

### The Moment of Truth

Open your browser: `http://192.168.50.10:3000/`

You should see `Hello World`.


## Node Configurations

At this moment the node's configuration is only stored on the server.
We definitely want to have this under version control.

```
chef-repo $ mkdir nodes
chef-repo $ knife node show example1 -Fj > nodes/example1.json
```

In future we will manage nodes by editing such files and then do

```
chef-repo $ knife node from file nodes/example1
```

# Summary

- We created a Client Virtual Machine using Vagrant.

```
nodejs-example $ vagrant up
```

- We manage foreign cookbooks using `librarian-chef` by editing `chef-repo/Cheffile`.

- To download all external cookbooks we have used

```
chef-repo $ librarian-chef install [--clean]
```

    Note: sometimes it is necessary to use the `--clean` option, e.g., when we bump a cookbook
    to a specific version `Cheffile.lock` gets in an inconsistent state.

- To install cookbooks onto the server we have used

```
chef-repo $ knife cookbook upload --all
```

    Note: you can remove uploaded cookbooks from the server using `knife cookbook delete`, using the web-interface,
    or `knife cookbook bulk delete "<regexp>"`. E.g., `knife cookbook bulk delete ".*"` removes all cookbooks.


- A new cookbook is created using

```
chef-repo $ knife cookbook create <COOKBOOK-NAME> -o site-cookbooks/
```

    Note: of course this is sugar and you can just create a cookbook manually if you know the directory layout.
    A minimal cookbook consists of `README.md`, `metadata.rb`, and `recipes/default.rb`.

- Cookbooks/Recipes are assigned to a Node via a *Run List*. The proper way to do this is to edit a node JSON file.

- To create a Node configuration file you can

```
chef-repo $ knife node show <NODE-NAME> -Fj > nodes/<NODE-NAME>.json
```

- Adding a Recipe to a run list looks like:

```
  "run_list": [
    "recipe[apt]"
  ]
```

- To store a Node configuration on the server you run:

```
chef-repo $ knife node from file nodes/<NODE-NAME>.json
```

- The client machine is updated using

```
nodejs-example $ vagrant provision
```


# Troubleshooting

## SSH fingerprint

```
ERROR: Net::SSH::HostKeyMismatch: fingerprint ae:ad:36:6f:da:ef:d5:2c:2e:db:2f:24:2c:10:15:3a does not match for "192.168.50.10"
```

This happens when we repeatedly create different VMs for the same URL. The ssh fingerprint changes and the registered
mismatches.

To solve this remove the entry from ~/.ssh/known_hosts.


## Librarian: probelm with installing `application_nodejs`

The following `Cheffile` entry:

```
cookbook 'application_nodejs'
```

leads to this error:

```
/chef-repo $ librarian-chef install
/usr/lib/ruby/1.9.1/fileutils.rb:1400:in `sub': invalid byte sequence in UTF-8 (ArgumentError)
  from /usr/lib/ruby/1.9.1/fileutils.rb:1400:in `block in remove_dir1'
  from /usr/lib/ruby/1.9.1/fileutils.rb:1411:in `platform_support'
  from /usr/lib/ruby/1.9.1/fileutils.rb:1399:in `remove_dir1'
  from /usr/lib/ruby/1.9.1/fileutils.rb:1392:in `remove'
  from /usr/lib/ruby/1.9.1/fileutils.rb:770:in `block in remove_entry'
  from /usr/lib/ruby/1.9.1/fileutils.rb:1444:in `block (2 levels) in postorder_traverse'
  ...
```

To resolve this use the repository notation:

```
cookbook 'application_nodejs',
  :git => 'https://github.com/conradev/application_nodejs',
  :ref => '2.0.0'
```

## Application >= 4.0.0 breaks other cookbooks

```
================================================================================
Error executing action `deploy` on resource 'deploy_revision[hello-world]'
================================================================================


NoMethodError
-------------
undefined method `application' for Chef::Resource::DeployRevision


Cookbook Trace:
---------------
/var/chef/cache/cookbooks/application_nodejs/providers/nodejs.rb:34:in `block (2 levels) in class_from_file'
/var/chef/cache/cookbooks/application/providers/default.rb:144:in `instance_eval'
/var/chef/cache/cookbooks/application/providers/default.rb:144:in `block (3 levels) in run_deploy'
/var/chef/cache/cookbooks/application/providers/default.rb:141:in `each'
/var/chef/cache/cookbooks/application/providers/default.rb:141:in `block (2 levels) in run_deploy'
```

Generally I found errors like `undefined method ...` always in conjunction with cookbook version incompatibilities.

To resolve this use application as of version `3.0.0`.


# Open Issues

- `application_nodejs` always builds from scratch which takes a long time. We could maybe fork that cookbook and
  make it use the package install.
