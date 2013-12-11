action :deploy do
  #ensure that the parent directory exists
  parent_directory = ::File.dirname(new_resource.path)
  directory parent_directory do
    action :create
    recursive true
  end

  link new_resource.path do
    to new_resource.source
  end

  propagate :before_compile
  propagate :before_migrate
  propagate :before_deploy

  propagate :before_restart
  run_restart
end

protected

def propagate (action)
  new_resource.sub_resources.each do |resource|
    resource.application_provider self
    resource.run_action action
  end
end

def run_restart
  new_resource.sub_resources.each do |resource|
    resource.application_provider self
    if resource.restart_command
      resource.restart_command.call
    end
  end
end
