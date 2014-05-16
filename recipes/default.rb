#
# Cookbook Name:: openstack-glance
# Recipe:: default
#
# Copyright 2014, FutureGrid, Indiana University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

secrets = Chef::EncryptedDataBagItem.load("openstack", "secrets")

openstack_mysql_user = secrets['mysql_user']
openstack_mysql_password = secrets['mysql_password']
openstack_admin_token = secrets['admin_token']
openstack_admin_password = secrets['admin_password']
openstack_service_password = secrets['service_password']
openstack_mysql_host = node["openstack"]["admin_address"]
openstack_public_address = node["openstack"]["public_address"]
openstack_internal_address = node["openstack"]["internal_address"]
openstack_admin_address = node["openstack"]["admin_address"]
glance_db = node['openstack']['glance_db']
rabbit_user = secrets['rabbit_user']
rabbit_password = secrets['rabbit_password']
rabbit_virtual_host = secrets['rabbit_virtual_host']

package "glance" do
	action :install
end

template "/etc/glance/glance-api.conf" do
  source "glance-api.conf.erb"
  mode "0644"
  owner "glance"
  group "glance"
  action :create
  variables(
    :openstack_admin_address => openstack_admin_address,
    :openstack_service_password => openstack_service_password,
    :openstack_mysql_password => openstack_mysql_password,
    :openstack_mysql_user => openstack_mysql_user,
    :openstack_mysql_host => openstack_mysql_host,
    :glance_db => glance_db,
    :rabbit_user => rabbit_user,
    :rabbit_password => rabbit_password,
    :rabbit_virtual_host => rabbit_virtual_host
  )
  notifies :restart, "service[glance-api]"
end

service "glance-api" do
  supports :restart => true
  restart_command "restart glance-api"
  action :nothing
end

template "/etc/glance/glance-registry.conf" do
  source "glance-registry.conf.erb"
  mode "0644"
  owner "glance"
  group "glance"
  action :create
  variables(
    :openstack_admin_address => openstack_admin_address,
    :openstack_service_password => openstack_service_password,
    :openstack_mysql_password => openstack_mysql_password,
    :openstack_mysql_user => openstack_mysql_user,
    :openstack_mysql_host => openstack_mysql_host,
    :glance_db => glance_db
  )
  notifies :restart, "service[glance-registry]"
end

service "glance-registry" do
  supports :restart => true
  restart_command "restart glance-registry"
  action :nothing
end

execute "glance_manage_db_sync" do
  user "glance"
  command "glance-manage db_sync && touch /etc/glance/.db_synced_do_not_delete"
  creates "/etc/glance/.db_synced_do_not_delete"
  action :run
	notifies :restart, "service[glance-api]"
  notifies :restart, "service[glance-registry]"
  notifies :run, "script[register_ubuntu1404]"
end

script "register_ubuntu1404" do
  interpreter "bash"
  user "root"
  cwd "/root"
  code <<-EOH
  wget http://uec-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
  source admin_credential
  glance image-create --name ubuntu-14.04 --disk-format qcow2 --container-format bare --is-public true --file ubuntu-14.04-server-cloudimg-amd64-disk1.img
  rm -f ubuntu-14.04-server-cloudimg-amd64-disk1.img
  touch /etc/glance/.register_ubuntu1404_do_not_delete
  EOH
  creates "/etc/glance/.register_ubuntu1404_do_not_delete"
  action :nothing
end
