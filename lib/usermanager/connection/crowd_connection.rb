require 'rest-client'
require 'json'

module UserManager
  class CrowdConnection < Connection
    
    def initialize(config, logger = nil)
      super(config, logger)
      
      @config = {}
      @config['host'] = config[:host] || 'localhost'
      @config['port'] = config[:port] || '8095'
      @config['username'] = config[:username] || 'test'
      @config['password'] = config[:password] || 'test'
      
      log("Crowd connection initializes")
    end
    
    def get_users
      ret = get_response("/usermanagement/1/search.json?entity-type=user")
      
      return nil if ret[:values].nil?
      
      ret = ret[:values]
      
      users = []
      ret['users'].each do |user|
        users << user['name']
      end
      
      return users
    end
    
    def get_groups
      ret = get_response("/usermanagement/1/search.json?entity-type=group")
      
      return nil if ret[:values].nil?
      
      ret = ret[:values]
      
      groups = []
      ret['groups'].each do |group|
        groups << group['name']
      end
      
      return groups
    end
    
    def create_user(user)
      log("Creating LDAP user: #{user['first']}")
      
      template = {
        'name' => user['username'],
        'first-name' => user['first'],
        'last-name' => user['last'],
        'display-name' => "#{user['first']} #{user['last']}",
        'email' => user['email'],
        'password' => {
          'value' => user['password']
        },
        'active' => true
      }
      
      ret = post_response("/usermanagement/1/user.json", template.to_json, 'application/json')
      
      return ret
    end
    
    def delete_user(user)
      ret = delete_response("/usermanagement/1/user.json?username=#{user['username']}")
      
      return ret
    end
    
    # Add user to Crowd groups
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    # @param [Array] groups
    #
    # @return [Hash] Returns a hash containing the result of the operation
    def add_user_to_groups(user, groups)
      groups.each do |group|
        template = {
           'name' => "#{group}"
        }
        
        post_response(
          "/usermanagement/1/user/group/direct.json?username=#{user['username']}",
          template.to_json,
          'application/json'
        )
      end
    end
    
    # Delete user from Crowd groups
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    # @param [Array] groups
    #
    # @return [Hash] Returns a hash containing the result of the operation
    def delete_user_from_groups(user, groups)
      groups.each do |group|
        ret = delete_response(
          "/usermanagement/1/user/group/direct.json?username=#{user['username']}&groupname=#{group}"
        )
        pp ["ret", ret]
      end
    end
    
    
    # Get groups a user belongs to
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    # @param [Array] groups
    #
    # @return [Array] Returns an array of groups a user is a member of
    def get_user_groups(user)
      ret = get_response("/usermanagement/1/user/group/direct.json?username=#{user['username']}")
      
      return nil if ret[:values].nil?
      
      ret = ret[:values]
      
      groups = []
      ret['groups'].each do |group|
        groups << group['name']
      end
      
      return groups
    end
    
    # Get Crowd parameters of a user
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    #
    # @return [Hash] Returns a hash of user parameters
    def get_user(user)
      ret = get_response("/usermanagement/1/user.json?username=#{user['username']}")
      
      return nil if ret[:values].nil?
      
      ret = ret[:values]
      
      user = {
        :username => ret['name'],
        :first => ret['first-name'],
        :last => ret['last-name'],
        :email => ret['email'],
        :active => ret['active']
      }
      
      return user
    end
    
    # Check if a user exists in Crowd
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
    
    def get_response(endpoint)
      response = RestClient::Resource.new(
        "http://#{@config['host']}:#{@config['port']}/crowd/rest#{endpoint}",
        @config['username'], @config['password']
      )
      
      begin
        ret = {
          :status => 1,
          :message => "Success",
          :values => JSON.parse(response.get)
        }
      rescue Exception => e
        case e.http_code
        when 404
          ret = {
            :status => 0,
            :message => "Not found: #{JSON.parse(e.response)['message']}",
            :values => nil
          }
        when 401
          ret = {
            :status => 0,
            :message => "Unauthorized: #{e.response}",
            :values => nil
          }
        else
          ret = {
            :status => 0,
            :message => "Unknown: #{e.http_code} #{e.response}",
            :values => nil
          }
        end
      end
      
      return ret
    end
    
    def post_response(endpoint, payload, content_type)
      response = RestClient::Resource.new(
        "http://#{@config['host']}:#{@config['port']}/crowd/rest#{endpoint}",
        @config['username'], @config['password']
      )
      
      begin
        ret = {
          :status => 1,
          :message => "Success",
          :values => response.post(payload, :content_type => content_type)
        }
      rescue Exception => e
        case e.http_code
        when 400
          ret = {
            :status => 0,
            :message => "Bad request: #{JSON.parse(e.response)['message']}"
          }
        when 401
          ret = {
            :status => 0,
            :message => "Unauthorized: #{e.response}",
            :values => nil
          }
        else
          ret = {
            :status => 0,
            :message => "Unknown: #{e.http_code} #{e.response}",
            :values => nil
          }
        end
      end
      
      return ret
    end
    
    def delete_response(endpoint)
      response = RestClient::Resource.new(
        "http://#{@config['host']}:#{@config['port']}/crowd/rest#{endpoint}",
        @config['username'], @config['password']
      )
      
      begin
        ret = {
          :status => 1,
          :message => "Success",
          :values => response.delete
        }
      rescue Exception => e
        case e.http_code
        when 400
          ret = {
            :status => 0,
            :message => "Bad request: #{JSON.parse(e.response)['message']}"
          }
        when 401
          ret = {
            :status => 0,
            :message => "Unauthorized: #{e.response}",
            :values => nil
          }
        else
          ret = {
            :status => 0,
            :message => "Unknown: #{e.http_code} #{e.response}",
            :values => nil
          }
        end
      end
    end
  end
end