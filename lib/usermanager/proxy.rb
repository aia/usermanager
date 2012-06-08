module UserManager
  class Proxy
    
    attr_accessor :config
    attr_accessor :logger
    attr_accessor :connections
    
    def initialize(config, logger = nil)
      @config = config
      
      @lh = logger || Logger.new(STDOUT)
      
      initialize_connections
    end
    
    # Log Message
    #
    # @param [String] message Message to log
    def log(message)
      @lh.info(message)
    end
    
    def initialize_connections
      @connections = {}
      
      @config.each_key do |key|
        @connections[key] = UserManager::Connection.create(key, @config[key], @logger)
      end
    end
    
    def connection(type)
      @connections[type]
    end
    
    def method_missing(method_name, *args, &block)
      res = {}
      
      @connections.each_key do |key|
        res[key] = @connections[key].send(method_name, *args, &block)
      end
      
      return res
    end
  end
end