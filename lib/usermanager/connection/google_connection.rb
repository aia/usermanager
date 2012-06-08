require 'googleapps/connection'
require 'googleapps/exceptions'
require 'googleapps/provisioningapi'

module UserManager
  class GoogleConnection < Connection
    
    # Initialize Google Apps connection
    #
    # @param [Hash] config Google Apps configuration parameters
    def initialize(config, logger = nil)
      super(config, logger)
      
      @config = {}
      @config['username'] = config[:username] || 'test'
      @config['password'] = config[:password] || 'test'
      
      @ds = GAppsProvisioning::ProvisioningApi.new(@config['username'], @config['password'])
      
      log("Google Apps connection initializes")
    end
    
    # Get all Google Apps users
    #
    # @return [Hash] Returns Google Apps users
    def get_users
      ret = @ds.retrieve_all_users
      
      return nil if ret.nil?
      
      users = []
      
      ret.each do |user|
        users << {
          :username => user.username,
          :first => user.given_name,
          :last => user.family_name,
          :active => user.suspended == "true" ? false : true,
          :admin => user.admin == "true" ? true : false,
        }
      end
      
      return users
    end
    
    # Get all Google Apps groups
    #
    # @return [Hash] Returns Google Apps groups
    def get_groups
      ret = @ds.retrieve_all_groups
      
      return nil if ret.nil?
      
      groups = []
      ret.each do |group|
        groups << group.group_id
      end
      
      return groups
    end
    
    # Create Google Apps user
    #
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    #
    # @return [Hash] 
    def create_user(user)
      log("Creating Google Apps user: #{user['first']}")
      return @ds.create_user(user['username'], user['first'], user['last'], user['password'])
    end
    
    # Delete Google Apps user
    #
    # @param [Hash] user User parameters - Username etc
    #
    # @return [Hash]
    def delete_user(user)
      return @ds.delete_user(user['username'])
    end
    
    # Add Google Apps user to the list of groups
    #
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    # @param [Array] groups Array of groups to add a user to
    #
    # @return [Hash]
    def add_user_to_groups(user, groups)
      groups.each do |group|
        @ds.add_member_to_group(user['email'], group)
      end
    end
    
    # Delete Google Apps user from the list of groups
    #
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    # @param [Array] groups Array of groups to add a user to
    #
    # @return [Hash]
    def delete_user_from_groups(user, groups)
      groups.each do |group|
        @ds.remove_member_from_group(user['email'], group)
      end
    end
    
    # Get groups a user belongs to
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    # @param [Array] groups
    #
    # @return [Array] Returns an array of groups a user is a member of
    def get_user_groups(user)
      log("User email information unavailable") if user['email'].nil?
      
      ret = @ds.retrieve_groups(user['email'])
      
      return nil if ret.nil?
      
      groups = []
      ret.each do |group|
        groups << group.group_id
      end
      
      return groups
    end
    
    # Get Google Apps parameters of a user
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    #
    # @return [Hash] Returns a hash of user parameters
    def get_user(user)
      begin
        ret = @ds.retrieve_user(user['username'])
      rescue Exception => e
        return nil
      end
      
      return nil if ret.nil?
      
      user = {
        :username => ret.username,
        :first => ret.given_name,
        :last => ret.family_name,
        :active => ret.suspended == "true" ? false : true,
        :admin => ret.admin == "true" ? true : false,
      }
      
      return user
    end
    
    # Check if a user exists in Google Apps
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    #
    # @return [Boolean] Returns true if user exists in LDAP and false otherwise
    def user_exists?(user)
      return !get_user(user).nil?
    end
    
    # Check if a user is a member of a group
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    #
    # @return [Hash] Returns true if user is a member of a group and false otherwise
    def user_in_group?(user, group)
      return get_user_groups(user).include?(group)
    end
  end
end