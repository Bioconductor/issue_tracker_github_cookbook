#
# Cookbook Name:: issue_tracker_github_cookbook
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'apt::default'

user = "ubuntu"

#pkgs = %W{build-essential gcc apache2 }

# change this with appropriate values from:
# https://www.phusionpassenger.com/library/install/apache/install/oss/trusty/
apt_repository 'passenger' do
  uri 'http://ppa.launchpad.net/juju/stable/ubuntu'
  components ['main']
  distribution 'trusty'
  key 'C8068B11'
  keyserver 'keyserver.ubuntu.com'
  action :add
  deb_src true
end
