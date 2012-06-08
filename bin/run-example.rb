#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'usermanager'

require 'pp'

STDOUT.sync = true

usage = "run.rb <json configuration file>"

if !ARGV[0].nil? && File.exists?(ARGV[0])
  config = JSON.parse(open(ARGV[0]).read, :symbolize_names => true)
else
  puts usage
  exit
end

manager = UserManager::Proxy.new(config)

username1 = {
  'username' => "username1",
  'password' => "secret",
  'email' => "username1@yourdomain.com",
  'first' => "User",
  'last' => "Name"
}

groups = {
  :crowd => [
    "crowd-group1",
    "crowd-group2"
  ],
  :google => [
    "google-group1",
    "google-group2"
  ],
  :ldap => [
    "ldap-group1",
    "ldap-group2"
  ]
}

pp ["ldap", manager.create_user(username1)]

groups.each_key do |key|
  pp [key, manager.connection(key).add_user_to_groups(username1, groups[key])]
end



