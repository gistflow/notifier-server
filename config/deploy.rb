require 'bundler/capistrano'
require "rvm/capistrano"

set :rvm_type, :system
set :rvm_ruby_string, '1.9.3@notifier-server'

set :application, "notifier-server"
set :domain, "git@gistflow.com"
set :repository,  "git://github.com/gistflow/notifier-server.git"
set :branch, "master"
set :use_sudo, false
set :keep_releases, 3
set :scm, :git

role :app, domain
role :web, domain

namespace :deploy do
  task :restart do
    run "kill -9 `cat #{deploy_to}/shared/pids/azazel.pid`" rescue nil
    run "cd #{release_path} && bundle exec ruby server.rb"
  end
end
