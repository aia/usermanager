$:.unshift File.join(File.dirname(__FILE__))

module UserManager
  VERSION = File.open(File.join(File.dirname(__FILE__), '..', 'VERSION')).read
end

require 'usermanager/connection'
require 'usermanager/proxy'