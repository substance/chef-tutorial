application "rails-example" do
  path '/var/www/rails/rails-example'
  owner 'www-data'
  group 'www-data'
  repository 'https://github.com/oliver----/rails-example.git'

  rails do
    bundler true
    database_template 'database.yml.erb'
  end

  passenger_apache2

end
