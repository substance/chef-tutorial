require 'weakref'

# Note: this pulls in support to create Resource instances via name
include Chef::DSL::Recipe

def initialize(*args)
  super
  @action = :deploy
  @sub_resources = []
end

actions :deploy, :restart

attribute :name, :kind_of => String, :name_attribute => true
attribute :environment_name, :kind_of => String, :default => (node.chef_environment =~ /_default/ ? "production" : node.chef_environment)
attribute :path, :kind_of => String
attribute :shared_folder, :kind_of => String, :default => "/vagrant"

# for compatibility
attribute :owner, :kind_of => String
attribute :group, :kind_of => String

attribute :application_provider
attr_reader :sub_resources

def release_path
  path
end

def shared_path
  path
end

def restart_command(arg=nil, &block)
  arg ||= block
  set_or_return(:restart_command, arg, :kind_of => [Proc, String])
end

# Support for sub-resources
# -------------------------
# A sub-resource as it is not an attribute of this resource will lead to a 'method_missing'.
# We then try to look-up the resource implementation.
# Either, the resource available directly (e.g., 'passenger_apache2')
# or it is a sub-resource of one of the 'application_*' cookbooks.
# Then the actual resource is "#{cookbook_name}_#{name}".
# Example:
# 'application_ruby' comes with a 'rails' resource.
# Using 'rails' within this resource leads to `method_missing('rails').
# The lookup 'application_ruby_rails'

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
      # Works on any MRI ruby
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

