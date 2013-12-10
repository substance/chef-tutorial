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
