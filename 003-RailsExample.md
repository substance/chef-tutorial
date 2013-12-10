# Preparation

As before there is a Vagrant configuration ready for you to start up a second machine for
this example.

```
rails-example $ vagrant up
```

# Rails Example Application

Here I will demonstrate a naive approach to creating a configuration to deploy a simple rails app
with sqlite3 as db.
Intentionally I will start with an incomplete solution and show errors and solutions.

## More Cookbooks

Add this to `chef-repo/Cheffile`:

```
cookbook 'nodejs'
cookbook 'application_ruby'
```

And run the Librarian:

```
chef-repo $ librarian-chef install
```

## Custom Cookbook

### Create a new cookbook

```
chef-repo $ knife cookbook create rails-example -o site-cookbooks
```

### Add dependencies

Open the file `chef-repo/site-cookbooks/rails-example/metadata.rb`:

```
depends          'nodejs'
depends          'git'
depends          'application_ruby'
```

    Note: we install nodejs as Javascript interpreter.


### Edit the Recipe

Open the file `chef-repo/site-cookbooks/rails-example/recipes/default.rb`:

```
application "rails-example" do
  path '/var/www/rails/rails-example'
  owner 'www-data'
  group 'www-data'
  repository 'https://github.com/oliver----/rails-example.git'
  rails
  passenger_apache2
```

Similar to the NodeJS Example we keep the application source code in an extra repository.
Again we make use of the `application` resource.
This time there are other sub-resources: `rails` provided by `application_ruby` and
`passenger_apache2` provided by `passenger_apache2`.
`rails` takes care of the Rails specific deployment, e.g., bundling.
`passenger_apache2` pulls in `apache2` and installs the passenger module.
end

### Edit attributes

Open the file `chef-repo/site-cookbooks/rails-example/attributes/default.rb`:

```
default['nodejs']['install_method'] = 'package'
default['nodejs']['version'] = '0.10.15'
```

### Upload Cookbooks

```
chef-repo $ knife cookbook upload --all
```

### Edit the Run-List:

Initialize the Node file:

```
chef-repo $ knife node show example2 -Fj > nodes/example2.json
```

Then open the Node file `chef-repo/nodes/example2.json` and edit the `run_list`:

```
  "run_list": [
    "recipe[apt]",
    "recipe[omnibus_updater]",
    "recipe[passenger_apache2]",
    "recipe[git]",
    "recipe[nodejs]",
    "recipe[rails-example]"
  ],
```

And write the node onto the server:

```
chef-repo $ knife node from file nodes/example2.json
```

## Fixing

At this moment you could try to update the client the first time.
However there are some problems to be solved.

### Rails config template

The `rails` recipe of `application_ruby` cookbook requires that we provide a template for the Rails app configuration
file.

Create the file `chef-repo/site-cookbooks/rails-example/templates/default/rails-example.conf.erb` with the following
content:

```
<VirtualHost *:80>
  # ServerName <%= @params[:server_name] %>
  ServerName 192.168.50.20
  ServerAlias <% @params[:server_aliases].each do |a| %><%= a %> <% end %>
  DocumentRoot <%= @params[:docroot] %>

  RailsBaseURI /
  RailsEnv <%= @params[:rails_env] %>

  <Directory <%= @params[:docroot] %>>
    Options FollowSymLinks
    AllowOverride None
    Order allow,deny
    Allow from all
  </Directory>

  LogLevel info
  ErrorLog <%= node['apache']['log_dir'] %>/<%= @params[:name] %>-error.log
  CustomLog <%= node['apache']['log_dir'] %>/<%= @params[:name] %>-access.log combined
</VirtualHost>
```

### No Bundle

We have to set the property `bundler` of resource `rails` to `true`.

```
application "rails-example" do
  ...
  rails do
    bundler true
  end
  ...
end

```

    Note: the bundler gets only triggered whenever the repository changed. When you have run `chef-client` before
    the `application` recipe will have cached the repository. To trigger the rebundle you must invalidate that cache.

```
rails-example $ vagrant ssh
[example2] ~/ $ sudo rm -rf /var/www/rails/rails-example
```

When you run

```
rails-example $ vagrant provision
```

you should see the bundler in action.


### Database.yml invalid

Even though we provided a `database.yml` with the application it gets overwritten by default by the `rails` recipe.
Instead it expects a template `database.yml.erb` to be provided.

Create a file `chef-repo/site-cookbooks/rails-example/templates/default/database.yml.erb` with the following content:

```
development:
  adapter: sqlite3
  database: db/development.sqlite3
  pool: 5
  timeout: 5000
test:
  adapter: sqlite3
  database: db/test.sqlite3
  pool: 5
  timeout: 5000
production:
  adapter: sqlite3
  database: db/production.sqlite3
  pool: 5
  timeout: 5000
```

Additionally, the template must be declared in the `rails` resource.
Open the default recipe of `rails-example` and edit the `rails` block:

```
application "rails-example" do
  ...
  rails do
    bundler true
    database_template 'database.yml.erb'
  end
  ...
end
```

### Update the client

```
chef-repo $ librarian-chef install
chef-repo $ knife cookbooks upload --all
```

```
rails-example $ vagrant provision
```

### Moment of Truth

Whe you open the browser at `192.168.50.20` you should see `Hello, Rails!`


# Summary

- We created a new cookbook that installs a rails application. This is mostly straight-forward except for some
  specialities of the `rails` recipe. Unfortunately, the documentation of the `application_ruby` cookbook lacks
  information about such requirements. Trial, Error, Know.

- We have seen some error logs and found solutions. Typically the error messages are rather good. Though, usually a lot
  of information is displayed (stack-traces). Try to find the way up to the first error.


# Troubleshooting

### Error during compile of Passenger Module

```
-----------------------------------------------
Your compiler failed with the exit status 4. This probably means that it ran out of memory. To solve this problem, try increasing your swap space: https://www.digitalocean.com/community/articles/how-to-add-swap-on-ubuntu-12-04

Tasks: TOP => apache2 => buildout/agents/PassengerHelperAgent => buildout/common/libpassenger_common/ApplicationPool2/Implementation.o
(See full trace by running task with --trace)
---- End output of /opt/chef/embedded/bin/ruby /opt/chef/embedded/lib/ruby/gems/1.9.1/gems/passenger-4.0.14/bin/passenger-install-apache2-module _4.0.14_ --auto ----
Ran /opt/chef/embedded/bin/ruby /opt/chef/embedded/lib/ruby/gems/1.9.1/gems/passenger-4.0.14/bin/passenger-install-apache2-module _4.0.14_ --auto returned 1
[2013-12-10T08:57:29+00:00] FATAL: Chef::Exceptions::ChildConvergeError: Chef run process exited unsuccessfully (exit code 1)
```

Make sure the VM has enough memory assigned. You need to rebuild the machine from scratch.


### Git not installed

```
[2013-12-10T09:07:45+00:00] ERROR: deploy_revision[rails-example] (/var/chef/cache/cookbooks/application/providers/default.rb line 122) had an error: Mixlib::ShellOut::ShellCommandFailed: Expected process to exit with [0], but received '127'
---- Begin output of git ls-remote "https://github.com/oliver----/rails-example.git" HEAD ----
STDOUT:
STDERR: sh: 1: git: not found
---- End output of git ls-remote "https://github.com/oliver----/rails-example.git" HEAD ----
Ran git ls-remote "https://github.com/oliver----/rails-example.git" HEAD returned 127
[2013-12-10T09:07:45+00:00] FATAL: Chef::Exceptions::ChildConvergeError: Chef run process exited unsuccessfully (exit code 1)
```

You need to add `recipe[git]` to the run list.


### Missing Rails config template

```
================================================================================
Error executing action `create` on resource 'template[/etc/apache2/sites-available/rails-example.conf]'
================================================================================


Chef::Exceptions::FileNotFound
------------------------------
Cookbook 'rails-example' (0.1.0) does not contain a file at any of these locations:
  templates/ubuntu-12.04/rails-example.conf.erb
  templates/ubuntu/rails-example.conf.erb
  templates/default/rails-example.conf.erb
```

The error message says everything. We need to provide a template for the rails configuration file.


### Apache says 'Forbidden'

```
Forbidden

You don't have permission to access / on this server.

Apache Server at 192.168.50.20 Port 80
```

Passenger is not running. I found this by look at `/var/log/apache2/error.log` on the client machine:

```
[Tue Dec 10 09:23:40 2013] [error] *** Passenger could not be initialized because of this error: Unable to start the Phusion Passenger watchdog because its executable (/opt/chef/embedded/lib/ruby/gems/1.9.1/gems/passenger-4.0.14/buildout/agents/PassengerWatchdog) does not exist. This probably means that your Phusion Passenger installation is broken or incomplete, or that your 'PassengerRoot' directive is set to the wrong value. Please reinstall Phusion Passenger or fix your 'PassengerRoot' directive, whichever is applicable.
[Tue Dec 10 09:23:40 2013] [notice] Apache/2.2.22 (Ubuntu) Phusion_Passenger/4.0.14 mod_ssl/2.2.22 OpenSSL/1.0.1 configured -- resuming normal operations
```

Make sure that the Passenger Module has been built properly. As a hack, you could log on the machine and
run the installer manually: `/opt/chef/embedded/lib/ruby/gems/1.9.1/gems/passenger-4.0.14/bin/passenger-install-apache2-module`


### Bundler has not been run

You see that in the browser:

```
Web application could not be started
Phusion Messenger has listed more information about the error below.

Could not find i18n-0.6.9 in any of the sources (Bundler::GemNotFound)
  /opt/chef/embedded/lib/ruby/gems/1.9.1/gems/bundler-1.1.5/lib/bundler/spec_set.rb:90:in `block in materialize'
  /opt/chef/embedded/lib/ruby/gems/1.9.1/gems/bundler-1.1.5/lib/bundler/spec_set.rb:83:in `map!'
  /opt/chef/embedded/lib/ruby/gems/1.9.1/gems/bundler-1.1.5/lib/bundler/spec_set.rb:83:in `materialize'
  /opt/chef/embedded/lib/ruby/gems/1.9.1/gems/bundler-1.1.5/lib/bundler/definition.rb:127:in `specs'
  /opt/chef/embedded/lib/ruby/gems/1.9.1/gems/bundler-1.1.5/lib/bundler/definition.rb:172:in `specs_for'
  /opt/chef/embedded/lib/ruby/gems/1.9.1/gems/bundler-1.1.5/lib/bundler/definition.rb:161:in `requested_specs'
  /opt/chef/embedded/lib/ruby/gems/1.9.1/gems/bundler-1.1.5/lib/bundler/environment.rb:23:in `requested_specs'
```

The bundler has not been running.
To resolve this set the `bundler` property in the `rails` resource to `true`.


### database.yml not properly defined


You see that in the browser:

```
Web application could not be started
Phusion Messenger has listed more information about the error below.

Could not load 'active_record/connection_adapters/_adapter'. Make sure that the adapter in config/database.yml is valid. If you use an adapter other than 'mysql', 'mysql2', 'postgresql' or 'sqlite3' add the necessary adapter gem to the Gemfile. (LoadError)
  /var/www/rails/rails-example/releases/2e156203698324f3962ec5ad5e696adaff94476b/vendor/bundle/ruby/1.9.1/gems/activesupport-4.0.2/lib/active_support/dependencies.rb:229:in `require'
  /var/www/rails/rails-example/releases/2e156203698324f3962ec5ad5e696adaff94476b/vendor/bundle/ruby/1.9.1/gems/activesupport-4.0.2/lib/active_support/dependencies.rb:229:in `block in require'
  /var/www/rails/rails-example/releases/2e156203698324f3962ec5ad5e696adaff94476b/vendor/bundle/ruby/1.9.1/gems/activesupport-4.0.2/lib/active_support/dependencies.rb:214:in `load_dependency'
  /var/www/rails/rails-example/releases/2e156203698324f3962ec5ad5e696adaff94476b/vendor/bundle/ruby/1.9.1/gems/activesupport-
```

Again the error message is very informative. *Make sure that the adapter in config/database.yml is valid*.
Be aware that `application_ruby` needs a template to be set, otherwise it will overwrite any existing file
with its stub file - which has lead to the error here.
