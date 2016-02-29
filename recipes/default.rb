#
# Cookbook Name:: issue_tracker_github_cookbook
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

# include_recipe "rails"
include_recipe 'apt::default'
include_recipe 'passenger_apache2'

user = "ubuntu"

user user do
  home "/home/#{user}"
  shell "/bin/bash"
  manage_home true
  action :create
end


#pkgs = %W{build-essential gcc apache2 }

# change this with appropriate values from:
# https://www.phusionpassenger.com/library/install/apache/install/oss/trusty/

package 'ruby-dev'

apt_repository 'passenger' do
  uri 'https://oss-binaries.phusionpassenger.com/apt/passenger'
  components ['main']
  distribution 'trusty'
  key 'C8068B11'
  keyserver 'keyserver.ubuntu.com'
  # does this need a not_if? hopefully not.
  # not_if File.exists? "/etc/apt/sources.list.d/passenger.list"
end

package 'libapache2-mod-passenger' do
  options '--force-yes -o Dpkg::Options::="--force-confdef"'
  # not sure why I need this not_if guard:
   not_if "dpkg --get-selections|grep -q libapache2-mod-passenger"
end

package 'git'

git "/home/#{user}/app" do
  repository "https://github.com/Bioconductor/issue_tracker_github.git"
  user user
end

git "/home/#{user}/.rbenv" do
  repository 'https://github.com/sstephenson/rbenv.git'
  user user
end

directory "/home/#{user}/.rbenv/plugins" do
  user user
end

git "/home/#{user}/.rbenv/plugins/ruby-build" do
    repository 'https://github.com/sstephenson/ruby-build.git'
    user user
end

%w[build-essential bison openssl libreadline6 libreadline6-dev
  zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-0
  libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev autoconf
  libc6-dev ssl-cert].each do |p|
    package p do
      options '--force-yes -o Dpkg::Options::="--force-confdef" '
      action :install
    end
  end

execute 'install ruby' do
  user user
  command "/home/#{user}/.rbenv/bin/rbenv install 2.3.0"
  not_if "/home/#{user}/.rbenv/bin/rbenv versions |grep -q 2.3.0"
  cwd "/home/#{user}"
  environment({PATH:  "#{ENV['PATH']}:/home/#{user}/.rbenv/bin",
    RBENV_ROOT: "/home/#{user}/.rbenv"})
end

execute 'set global ruby' do
  user user
  command "/home/#{user}/.rbenv/bin/rbenv global 2.3.0"
  environment({RBENV_ROOT: "/home/#{user}/.rbenv"})
  not_if "/home/#{user}/.rbenv/bin/rbenv version |grep -q 2.3.0"
end


execute 'rehash' do
  user user
  command "/home/#{user}/.rbenv/bin/rbenv rehash"
  environment({RBENV_ROOT: "/home/#{user}/.rbenv"})
  # how to guard?
end


execute 'install bundler' do
  user user
  command "/home/#{user}/.rbenv/shims/gem install bundler"
  environment({RBENV_ROOT: "/home/#{user}/.rbenv"})
  # how to guard?
  not_if "/home/#{user}/.rbenv/shims/gem list |grep -q bundler"
end

execute 'rehash again' do
  user user
  command "/home/#{user}/.rbenv/bin/rbenv rehash"
  environment({RBENV_ROOT: "/home/#{user}/.rbenv"})
  # how to guard?
end


execute 'bundle install' do
  user user
  cwd "/home/#{user}/app"
  command "/home/#{user}/.rbenv/shims/bundle install && touch /tmp/bundle_install"
  environment({RBENV_ROOT: "/home/#{user}/.rbenv"})
  # don't guard.
end



__END__

web_app "app" do
  docroot "/home/#{user}/app/public"
  server_name "issues.bioconductor.org"
  rails_env "production"
end
