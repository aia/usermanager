require 'logger'

module UserManager
  class Connection
    
    # @return [Hash] Connection configuration reference
    attr_accessor :config
    
    # Initialize connection
    #
    # @param [Hash] config Connection configuration parameters
    # @param [Logger] logger Logger class, optional
    def initialize(config, logger = nil)
      @lh = logger || Logger.new(STDOUT)
    end
    
    # Log Message
    #
    # @param [String] message Message to log
    def log(message)
      @lh.info(message)
    end
    
    # Factory method to create connection objects of a specific type
    #
    # @param [Symbol] type Message to log
    # @param [Hash] config Connection configuration parameters
    # @param [Logger] logger Logger class, optional
    def self.create(type, config, logger = nil)
      begin
        Object.const_get(:UserManager).const_get("#{type.capitalize}Connection").new(config, logger)
      rescue Exception => e
        nil
      end
    end
  end
end

Dir["#{File.dirname(__FILE__)}/connection/*.rb"].each { |f| require f }