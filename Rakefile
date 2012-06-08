# encoding: utf-8

$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.name = "usermanager"
  gem.homepage = "http://github.com/aia/usermanager"
  gem.license = "Apache"
  gem.summary = %Q{UserManager is an account management automation library}
  gem.description = %Q{UserManager is an account management automation library}
  gem.email = "artem@veremey.net"
  gem.authors = ["Artem Veremey"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

if RUBY_VERSION =~ /^1\.9/
  desc "Code coverage detail"
  task :simplecov do
    ENV['COVERAGE'] = "true"
    Rake::Task['spec'].execute
  end
else
  RSpec::Core::RakeTask.new(:rcov) do |spec|
    spec.pattern = 'spec/**/*_spec.rb'
    spec.rcov = true
  end
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:features)

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new
