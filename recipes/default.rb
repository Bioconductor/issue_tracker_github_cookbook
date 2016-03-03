#
# Cookbook Name:: issue_tracker_github_cookbook
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

# include_recipe "rails"
include_recipe 'apt::default'

user = "www-data"
userhome = "/var/www"


# IMPORTANT NOTE! When running on a fresh node in the UB
# cloud, you have to manually ssh to the node and do this before
# running chef-client:
# sudo -s
#  cd /etc
# cp hostname hostname.bak
# echo issues.bioconductor.org > hostname
# hostname -F hostname
# hostname
# Hmm...not sure if that was really necessary, it may be that just
# running chef-client a couple times fixes it. Or it may be
# necessary to run chef-client a couple of times but ONLY after
# making the hostname change.
# You can then bootstrap as follows:
# (may need to adjust paths to keys and secrets):
# knife bootstrap issues.bioconductor.org  -N issues.bioconductor.org \
# -x ubuntu --secret-file encrypted_data_bag_secret \
# -i ~/.ub/dtenenba-ub.pem --sudo

# bootstrap like this if the node is on ec2:
# knife bootstrap issues.bioconductor.org  --hint ec2  -N issues.bioconductor.org -x ubuntu --secret-file encrypted_data_bag_secret -i ~/.ec2/bioc-default.pem  --sudo


# -- then add this recipe to the run list:
#  knife node run_list set issues.bioconductor.org \
# "recipe[issue_tracker_github_cookbook::default]"
# -- then run chef-client:
# knife ssh "name:issues.bioconductor.org" -x ubuntu -i ~/.ub/dtenenba-ub.pem \
# "sudo chef-client"
# like this on ec2:
# knife ssh "name:issues.bioconductor.org" -x ubuntu -i ~/.ec2/bioc-default.pem  -a ec2.public_ipv4  "sudo chef-client"


#pkgs = %W{build-essential gcc apache2 }

# change this with appropriate values from:
# https://www.phusionpassenger.com/library/install/apache/install/oss/trusty/

package 'ruby-dev'
package 'build-essential'

%w[build-essential openssl libreadline6 libreadline6-dev
  zlib1g zlib1g-dev libssl-dev libsqlite3-0
  libsqlite3-dev sqlite3 libxml2-dev autoconf
  libc6-dev ssl-cert].each do |p|
    package p do
      action :install
    end
  end




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

package 'apache2' # creates 'user' user and 'userhome' directory

# but we want to be able to log in as 'user'
user user do
  home "#{userhome}"
  shell "/bin/bash"
  manage_home true
  action :create
end


# and to own userhome...
directory userhome do
  action :create
  owner user
  group user
end


execute 'install apache2 ssl module' do
  command "a2enmod ssl"
  not_if "apache2ctl -M |grep -q ssl"
end


package 'git'

git "#{userhome}/app" do
  repository "https://github.com/Bioconductor/issue_tracker_github.git"
  user user
end

git "#{userhome}/.rbenv" do
  repository 'https://github.com/sstephenson/rbenv.git'
  user user
end

directory "#{userhome}/.rbenv/plugins" do
  user user
end

git "#{userhome}/.rbenv/plugins/ruby-build" do
    repository 'https://github.com/sstephenson/ruby-build.git'
    user user
end


execute 'install ruby' do
  user user
  command "#{userhome}/.rbenv/bin/rbenv install 2.3.0"
  not_if "#{userhome}/.rbenv/bin/rbenv versions |grep -q 2.3.0"
  cwd userhome
  environment({PATH:  "#{ENV['PATH']}:#{userhome}/.rbenv/bin",
    RBENV_ROOT: "#{userhome}/.rbenv",
    RUBY_CONFIGURE_OPTS: "--disable-install-doc"})
end

execute 'set global ruby' do
  user user
  command "#{userhome}/.rbenv/bin/rbenv global 2.3.0"
  environment({RBENV_ROOT: "#{userhome}/.rbenv"})
  not_if "#{userhome}/.rbenv/bin/rbenv version |grep -q 2.3.0"
end


execute 'rehash' do
  user user
  command "#{userhome}/.rbenv/bin/rbenv rehash"
  environment({RBENV_ROOT: "#{userhome}/.rbenv"})
  # how to guard?
end


execute 'install bundler' do
  user user
  command "#{userhome}/.rbenv/shims/gem install bundler"
  environment({RBENV_ROOT: "#{userhome}/.rbenv"})
  # how to guard?
  not_if "#{userhome}/.rbenv/shims/gem list |grep -q bundler"
end

execute 'rehash again' do
  user user
  command "#{userhome}/.rbenv/bin/rbenv rehash"
  environment({RBENV_ROOT: "#{userhome}/.rbenv"})
  # how to guard?
end


execute 'bundle install' do
  user user
  cwd "#{userhome}/app"
  command "#{userhome}/.rbenv/shims/bundle install && touch /tmp/bundle_install"
  environment({RBENV_ROOT: "#{userhome}/.rbenv"})
  # don't guard.
end

## The following stuff assumes that the node has
## the secret key for decrypting data bag items.

file "#{userhome}/app/auth.yml" do
  # content data_bag_item('IssueTrackerConfig',
  #   'IssueTrackerConfig').raw_data['value'].to_yaml
  content Chef::EncryptedDataBagItem.load('IssueTrackerConfig',
    'IssueTrackerConfig')['value'].to_yaml
  owner user
  group user
  mode '0755'
end

file "/etc/ssl/certs/_.bioconductor.org.crt" do
  # content data_bag_item('bioc-ssl', 'bioconductor.org.crt').raw_data['value']
  content Chef::EncryptedDataBagItem.load('bioc-ssl',
    'bioconductor.org.crt')['value']
  owner "root"
  group "root"
  mode '0644'
end

file "/etc/ssl/private/bioconductor.org.key" do
  # content data_bag_item('bioc-ssl', 'bioconductor.org.key').raw_data['value']
  content Chef::EncryptedDataBagItem.load('bioc-ssl',
    'bioconductor.org.key')['value']
  owner "root"
  group "root"
  mode '0400'
end

file "/etc/ssl/certs/gd_bundle-g2-g1.crt" do
  # content data_bag_item('bioc-ssl', 'gd_bundle-g2-g1.crt').raw_data['value']
  content Chef::EncryptedDataBagItem.load('bioc-ssl',
    'gd_bundle-g2-g1.crt')['value']
  owner "root"
  group "root"
  mode '0644'
end

execute "change default ruby used by passenger" do
  command 'sed -i.bak  "s:/usr/bin/passenger_free_ruby:/var/www/.rbenv/shims/ruby:" passenger.conf'
  cwd "/etc/apache2/mods-available"
  not_if "grep -q shims /etc/apache2/mods-available/passenger.conf"
end

execute "tell apache about passenger app" do
  command 'sed -i.bak  "s:DocumentRoot /var/www/html:DocumentRoot /var/www/app/public\\n<Directory /path/to/app/public>\\n        Require all granted\\n        Allow from all\\n        Options -MultiViews\\n    </Directory>:" 000-default.conf'
  cwd "/etc/apache2/sites-available"
  not_if "grep -q MultiViews /etc/apache2/sites-available/000-default.conf"
end

link "/etc/apache2/mods-enabled/passenger.conf" do
  to "/etc/apache2/mods-available/passenger.conf"
end

link "/etc/apache2/mods-enabled/passenger.load" do
  to "/etc/apache2/mods-available/passenger.load"
end

# FIXME probably need a way to guard against unwanted service
# restarts in production. Not sure yet how to do that.
service "apache2" do
  action :restart
end

# FIXME deal with this issue:
# App 435 stderr:  [passenger_native_support.so] trying to compile for the current user (www-data) and Ruby interpreter...
# App 435 stderr:
# App 435 stderr:      (set PASSENGER_COMPILE_NATIVE_SUPPORT_BINARY=0 to disable)
# App 435 stderr:
# App 435 stderr:      Warning: compilation didn't succeed. To learn why, read this file:
# App 435 stderr:      /tmp/passenger_native_support-141773w.log
# App 435 stderr:  [passenger_native_support.so] not downloading because passenger wasn't installed from a release package
# App 435 stderr:  [passenger_native_support.so] will not be used (can't compile or download)
# App 435 stderr:   --> Passenger will still operate normally.
# App 484 stdout:


# the log file referenced has these contents (lines starting with ## are not actually commented)
##$ cat /tmp/passenger_native_support-141773w.log
# current user is: www-data
# mkdir -p /usr/lib/buildout/ruby/ruby-2.3.0-x86_64-linux
##Encountered permission error, trying a different directory...
##-------------------------------
# mkdir -p /var/www/.passenger/native_support/5.0.26/ruby-2.3.0-x86_64-linux
# cd /var/www/.passenger/native_support/5.0.26/ruby-2.3.0-x86_64-linux
# /var/www/.rbenv/versions/2.3.0/bin/ruby /usr/lib/src/ruby_native_extension/extconf.rb
##/var/www/.rbenv/versions/2.3.0/bin/ruby: No such file or directory -- /usr/lib/src/ruby_native_extension/extconf.rb (LoadError)
