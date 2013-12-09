# Client Machine

You find everything prepared in `./nodejs-example`.

```
/ $ cd nodejs-example
/nodejs-example $ vagrant up
```

After that you should have a client running on `192.168.50.10`
If you want you can create an alias in `/etc/hosts`

```
192.168.50.10 example1.substance.io example1
```

# Registration

## Quick Start

```
/nodejs-example $ ./register.sh
```

## Step by step

Remove an old node from the server. You can use the WebInterface or run (from `chef-repo` folder):

```
/chef-repo $ knife delete node example1 2> /dev/null
/chef-repo $knife delete client example1 2> /dev/null
```

Bootstrap the client machine

```
/chef-repo $ knife bootstrap 192.168.50.10 --sudo -x vagrant -P vagrant -N "example1"
```

## Snapshot

If you want to play around now (i.e., after registration) is a good moment to take a snapshot.

```
/chef-repo $ cd ../nodejs-example
/nodejs-example $ vagrant snapshot take vanilla
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
/chef-repo $ librarian-chef install
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
/chef-repo $ knife cookbook upload --all
```

# NodeJS Example

As NodeJS application we use a HelloWorld express application.

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

# Troubleshooting

```
ERROR: Net::SSH::HostKeyMismatch: fingerprint ae:ad:36:6f:da:ef:d5:2c:2e:db:2f:24:2c:10:15:3a does not match for "192.168.50.10"
```

This happens when we repeatedly create different VMs for the same URL. The ssh fingerprint changes and the registered
mismatches.

To solve this remove the entry from ~/.ssh/known_hosts.
