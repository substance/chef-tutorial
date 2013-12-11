
local_application "hello-world" do
  path "/var/www/nodejs/hello-world"
  source "/projects/hello-world"
  nodejs do
    entry_point "app.js"
  end
end
