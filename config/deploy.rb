local_user = ENV['USER'] || ENV['USERNAME']
set :user, local_user

set :ssh_options, {:forward_agent => true}
on :start do    
  `ssh-add`
end

set :scm, :git
set :repository,  "git@github.com:intergi/console_api.git"
set :keep_releases, 2


set :deploy_via, :export
set :use_sudo, true


if ENV['DEPLOY'] == 'PROD'
  puts "*** Deploying to the PRODUCTION server ***"
  set :branch, 'live'
  
  role :web, 'cerberus.gamezone.com'
  role :app, 'cerberus.gamezone.com'
  set :application, "cerberus"

  port = 80
else
  puts "*** Deploying to the STAGING server ***"
  set :branch, 'master'

  role :web, 'cerberus.gamezone.com'
  role :app, 'cerberus.gamezone.com'

  set :application, "cerberus-staging"
  port = 8080
end

set :deploy_to, "/www/#{application}"

default_run_options[:pty] = true

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  task :start do ; end

  task :stop do ; end

  task :initial, :roles => :app do
    #sudo "mkdir -p #{deploy_to}/shared/logs"
  end

  task :fix_permissions, :except => { :no_release => true }, :on_error => :continue do
    sudo "chown -R www-data:www-data #{deploy_to}"
    sudo "chmod -R 755 #{deploy_to}"

    #sudo "chown -R ryanfaerman:ryanfaerman #{shared_path}"
    #sudo "chmod -R 766 #{shared_path}"

    #sudo "chown -R ryanfaerman:ryanfaerman #{current_path}"
    #sudo "chmod -R 766 #{current_path}"
  end

  task :setup_shared_data, :roles => :app, :on_error => :continue do
    sudo "mkdir #{shared_path}/logs"
    sudo "ln -s #{shared_path}/logs #{release_path}/logs"
  end

  task :start, :roles => :app do
    #run "echo {} > #{current_path}/lib/cookies.json"
    sudo "/etc/init.d/#{application} start"
  end
  task :stop do 
    sudo "/etc/init.d/#{application} stop"
  end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "echo {} > #{current_path}/lib/cookies.json"
    sudo "/etc/init.d/#{application} restart"
  end
end

namespace :npm do
  task :install, :roles => [:app] do
    #run "cd #{current_path}"
    run "cd #{release_path} && rm -rf node_modules && npm install"
  end
end

after "deploy:update_code", "npm:install"
#before "deploy:symlink", "deploy:stop"
after "deploy:symlink", "deploy:restart"
after "deploy:setup", "deploy:fix_permissions"
after "deploy:update_code", "deploy:setup_shared_data"




