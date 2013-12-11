
local_application "hello-world" do
  path "/var/www/nodejs/hello-world"
  shared_folder "/project"
  nodejs do
    entry_point "app.js"
  end
end
