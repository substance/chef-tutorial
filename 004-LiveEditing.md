# Preparation

Create the virtual machine for this example.

```
liveedit-client $ vagrant up
```

# Application Cookbook for Live-Editing

We want to create something like the `application` cookbook but which in contrast allows to work with a shared folder
instead of a git repository.
This is particularly interesting for development, where you want to see your changes instantly.
At the same time this cookbook shall be as close as possible to the deployment scenario.

Create a cookbook named `local_application`:

```
chef-repo $ knife cookbook create local_application -o site-cookbooks
```

## Resources and Providers

Chef resources describe some kind of structure or functionality to be configured.
In the examples before we used the `application` resource to specify the installation of an application.

```
application 'my_app' do
  ...
end
```

Every resource type is defined in a cookbook's `resources` folder. The main resource of a cookbook
is specified in `resources/default.rb` and it has the same name as the cookbook. E.g., the `application` resource
is defined in `application/resources/default.rb`.
It is possible to specify additional resources which will be sub-scoped. E.g., the `apt` cookbook
defines a resource `repository` which would be used as follows:

```
apt_repository do
 ...
end
```

A resource implementation looks basically like this

```
# Initialization

def initialize(*args)
  super
  # initialization stuff
end

# Actions

actions :deploy

# Attributes

attribute :name, :kind_of => String, :name_attribute => true

# Instance methods

def restart_command(arg=nil, &block)
  arg ||= block
  set_or_return(:restart_command, arg, :kind_of => [Proc, String])
end

```

Along with each resource there comes a Provider in the `providers` folder. Every resource has an associated action and providers implement the action handlers.
For instance, the `application` resource has a `deploy` action. The corresponding provider
is implemented in `application/providers/default.rb` which contains:

```
action :deploy do
  before_compile
  before_deploy
  run_deploy
end
```

All this as classical Ruby code. So you can do what you are able to do with Ruby.


## Resource specification

Open the file `site-cookbooks/local_application/resources/default.rb` and add the following content:

```
def initialize(*args)
  super
  @action = :deploy
end

actions :deploy

attribute :name, :kind_of => String, :name_attribute => true
attribute :environment_name, :kind_of => String, :default => (node.chef_environment =~ /_default/ ? "production" : node.chef_environment)
attribute :path, :kind_of => String
attribute :source, :kind_of => String

```

This defines a resource called `local_application` which has the following attributes:

- `name`: the name of the application
- `environment_name`: this will be `production`, `stage`, or `development`
- `path`: the folder where the application should be installed on the virtual machine
- `source`: the folder where the application is located. This will be a folder that we will make available via shared
  folder.

## Provider Stub implementation

Open the file `site-cookbooks/local_application/providers/default.rb` and add the following content:

```
action :deploy do

  # Ensure that the parent directory exists
  parent_directory = ::File.dirname(new_resource.path)
  directory parent_directory do
    action :create
    recursive true
  end

  # Create a link to the source folder
  link new_resource.path do
    to new_resource.source
  end

end
```

This will create a symbolic link in the deploy folder (e.g., `/var/www/nodejs) pointing to the specified
application source folder.


## Integration

At this moment we are already able to use the defined resource. However, it does not do anything.
Create a cookbook called `liveedit-example`:

```
chef-repo $ knife cookbook create liveedit-example -o site-cookbooks
```

Open the file `site-cookbooks/liveedit-example/recipes/default.rb` and add this content:

```
local_application "hello-world" do
  path "/var/www/nodejs/hello-world"
  source "/projects/hello-world"
end
```

    Note: at this moment we can not yet make use of the `nodejs` sub-resource. We will address this next.

Upload the cookbooks:

```
chef-repo $ knife cookbook upload --all
```

Initialize the Node configuration file:

```
chef-repo $ knife node show liveedit-example -Fj > nodes/liveedit-example.json
```

Open this file and edit the run list:

```
  "run_list": [
    "recipe[apt]",
    "recipe[liveedit-example]"
  ]
```

Upload the Node configuration:

```
chef-repo $ knife node from file nodes/liveedit-example.json
```

Update the client:

```
liveedit-client $ vagrant provision
```

This should run without any errors.
To check the success we need to log on to the client machine

```
liveedit-client $ vagrant ssh
[liveedit-client] ~/ $ ls /var/www/nodejs/hello-world
app.js package.json
```
You should sse the content of the folder `liveedit-client/hello-world`.


## Supporting Sub-Resoure types

We want to be able to use the sub-resources as provided by `application_nodejs` or `application_ruby`.
For that to work we need to catch any access to the resource that is not a specified resource attribute
and then try to spawn the corresponding resource for it. In Ruby we can add a `missing_method` implementation to
do that.

Open the file `site-cookbooks/local_application/resources/default.rb`.

### Adapt the resource specification:

```
def initialize(*args)
  super
  @action = :deploy
  @sub_resources = []
end

attr_reader :sub_resources
```

We provided place to store references to sub-resources.


### Add this at the top of the file:

```
require 'weakref'
include Chef::DSL::Recipe
```

    Note: 'weakref' will be used to store a reference to the sub-resource instance.
    `Chef::DSL::Recipe` provides many things, one of it is to look up a resource by name.


### Add this instance method:

```
def method_missing(name, *args, &block)
  # Creates a lookup entry for all cookbooks starting with 'application_',
  # e.g., application_ruby_rails.
  lookup_path = ["application_#{name}"]
  run_context.cookbook_collection.each do |cookbook_name, cookbook_ver|
    if cookbook_name.start_with?("application_")
      lookup_path << "#{cookbook_name}_#{name}"
    end
  end
  lookup_path << name
  resource = nil
  # Try to find our resource
  lookup_path.each do |resource_name|
    begin
      Chef::Log.debug "Trying to load application resource #{resource_name} for #{name}"
      # Note: using the super method_missing implementation to try to load the resource
      # if successful the break condition is reached,
      # otherwise we catch the NameError and continue the iteration
      resource = super(resource_name.to_sym, self.name, &block)
      break
    rescue NameError => e
      if e.name == resource_name.to_sym || e.inspect =~ /\b#{resource_name}\b/
        next
      else
        raise e
      end
    end
  end
  raise NameError, "No resource found for #{name}. Tried #{lookup_path.join(', ')}" unless resource
  # Enforce action :nothing in case people forget
  resource.action :nothing
  # Make this a weakref to prevent a cycle between the application resource and the sub resources
  resource.application WeakRef.new(self)
  resource.type name
  @sub_resources << resource
  resource
end
```

I don't want to go in detail here. This implementation takes care of instantiating a sub-resource by name.


### Complement the integration recipe:

```
local_application "hello-world" do
  path "/var/www/nodejs/hello-world"
  source "/projects/hello-world"
  nodejs do
    entry_point "app.js"
  end
end
```

### Update

Upload the cookbooks and provision the client.

```
chef-repo $ knife cookbook upload --all
```

```
liveedit-client $ vagrant provision
```

This should again run without errors. However, we are still not there.


## Connecting Sub-Resource Handlers

Open the file `site-cookbooks/local_application/provides/default.rb`.

Adapt the content:

```
action :deploy do
  ...

  propagate :before_compile
  propagate :before_migrate
  propagate :before_deploy

  propagate :before_restart
  run_restart
end

protected

def propagate (action)
  new_resource.application_provider self
  new_resource.sub_resources.each do |resource|
    resource.application_provider self
    resource.run_action action
  end
end

def run_restart
  new_resource.application_provider self
  new_resource.sub_resources.each do |resource|
    resource.application_provider self
    if resource.restart_command
      resource.restart_command.call
    end
  end
end
```

We implemented the deploy lifecycle in one method, which is carried out by the `application` cookbook usually.

### Compatibility

There are some resource attributes that are used by the sub-resource providers.

Open the file `site-cookbooks/local_application/resources/default.rb` and add the following attributes and methods:

```
attribute :owner, :kind_of => String
attribute :group, :kind_of => String

def release_path
  path
end

def shared_path
  path
end
```

### Update

Upload the cookbooks and provision the client.

```
chef-repo $ knife cookbook upload --all
```

```
liveedit-client $ vagrant provision
```

This should now take a while as nodejs is getting built.
After that you should be able to see `Hello World!` when you browser (or curl) `192.168.50.30:3000`.

```
$ curl 192.168.50.30:3000
Hello World!
```

## Live Editing

Now you can edit the application source locally.
However, our NodeJS application needs to be restarted to reflect file changes.
There are two ways to do that.

```
liveedit-client $ vagrant provision
```

This does a full chef-client run, which takes about 5-10 seconds.  To my personal feeling this is too slow for live editing. Thus I prefer the next option.

```
liveedit-client $ vagrant ssh
[liveedit-client] $ sudo service hello-world_nodejs restart
```

The name of the service depends on the chef resource name. Let's have a look at the application definition.

```
application "hello-world" do
   ...
end
```

The Upstart service for a NodeJS application follows this pattern: `"#{application.name}_nodejs"`, which is in
our case `hello-world_nodejs`.

# Summary

We learned how to write a more sophisticated cookbook providing a resource type that
may be used as a substitute for the `application` resource.
Adopting vagrant's shared folder we can use a local application source folder instead of a a remote repository.

Now we know how to implement the concept of a resource and a corresponding provider.
In our implementation we can make use of built-in resources in the same way as it is done on a higher level.
It is all plain Ruby code.

# Troubleshooting

I had no special problems myself.
Please try out and give me feedback about the troubles you had.
