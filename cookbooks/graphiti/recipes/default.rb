#
# Cookbook Name:: graphite
# Recipe:: default
#
# Copyright 2012, AJ Christensen <aj@junglist.gen.nz>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
include_recipe "build-essential"

%w[libcurl4-gnutls-dev].each do |pkg|
  apt_package pkg
end

gem_package "bundler"

remote_file node.graphiti.tarfile do
  mode "00666"
  owner "www-data"
  group "www-data"
  source node.graphiti.url
  action :create_if_missing
end

directory node.graphiti.base do
  owner "www-data"
  group "www-data"
end

directory File.join(node.graphiti.base, "log") do
  owner "www-data"
  group "www-data"
end

execute "bundle" do
  command "bundle install --deployment --binstubs; " +
    "bundle exec rake graphiti:metrics"

  user "www-data"
  group "www-data"
  cwd node.graphiti.base
  action :nothing
end

cron "graphiti:metrics" do
  minute "*/15"
  command "cd #{node.graphiti.base} && bundle exec rake graphiti:metrics"
  user "www-data"
end

execute "graphiti: untar" do
  command "tar zxf #{node.graphiti.tarfile} -C #{node.graphiti.base} --strip-components=1"
  creates File.join(node.graphiti.base, "Rakefile")
  user "www-data"
  group "www-data"
  notifies :run, resources(:execute => "bundle"), :immediately
end

template File.join(node.graphiti.base, "config", "settings.yml") do
  owner "www-data"
  group "www-data"

  notifies :restart, "service[graphiti]"
end

directory "/var/run/unicorn" do
  owner "www-data"
  group "www-data"
end

template File.join(node.graphiti.base, "config", "unicorn.rb") do
  owner "www-data"
  group "www-data"
  variables( :worker_processes => 1,
             :timeout => node.graphiti.unicorn.timeout,
             :cow_friendly => node.graphiti.unicorn.cow_friendly )
  notifies :restart, "service[graphiti]"
end

runit_service "graphiti"

