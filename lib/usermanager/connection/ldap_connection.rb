require 'net/ldap'
require 'unix_crypt'
require 'ntlm/util'
require 'erb'

module UserManager
  class LdapConnection < Connection
    
    # Initialize LDAP connection
    #
    # @param [Hash] config LDAP configuration parameters
    def initialize(config, logger = nil)
      super(config, logger)
      
      @config = config
      
      @config[:templates].each_key do |key|
        next if @config[:templates][key].class == ERB
        @config[:templates][key] = ERB.new(JSON.generate(@config[:templates][key]))
      end
      
      @config[:auth][:method] = @config[:auth][:method].to_sym
      
      unless @config[:encryption].nil?
         @config[:encryption] = @config[:encryption].to_sym
      end
      
      @ds = Net::LDAP.new(@config)
      
      log("LDAP connection initialized")
    end
    
    # Get all LDAP user
    # 
    # @return [Array] Returns an of LDAP users
    def get_users
      res = search(@config[:userdn])
      
      if (res[:message] != "Success")
        # tbd handle error
        return nil
      end
      
      if (res[:values] == [])
        return nil
      end
      
      users = []
      
      res[:values].each do |user|
        begin
          uid = user.uidnumber.first
          gid = user.gidnumber.first
        rescue
          uid = 0
          gid = 0
        end
        
        users << {
          :username => user.uid.first,
          :uid => uid,
          :gid => gid,
          :first => user.givenname.first,
          :last => user.sn.first
        }
      end
      
      return users
    end
    
    # Get all LDAP groups
    # 
    # @return [Array] Returns an of LDAP groups
    def get_groups
      res = search(@config[:groupdn])
      
      if (res[:message] != "Success")
        # tbd handle error
        return nil
      end
      
      if (res[:values] == [])
        return nil
      end
      
      groups = []
      
      res[:values].each do |group|
        groups << group.cn.first
      end
      
      return groups
    end
    
    # Create an LDAP user
    #
    # @param [Hash] user User parameters - Firstname, Lastname, Password etc
    #
    # @return [Hash] Returns a hash containing the result of the operation
    def create_user(user)
      log("Creating LDAP user: #{user['first']}")
      
      params = {
        :first => user['first'],
        :last => user['last'],
        :username => user['username'],
        :uid => find_uid(@config[:userdn], { :low => 10000, :high => 12000 })[:values].to_s,
        :passwd => crypt3(user['password']),
        :lmpasswd => lm_hash(user['password']),
        :ntpasswd => nt_hash(user['password']),
        :time => Time.now.to_i.to_s
      }
      
      new_user = JSON.parse(
        @config[:templates][:user].result(binding),
        :symbolize_names => true
      )
      
      # TBD: wrap the add call
      add(
        {:name => "localuser", :ip => "127.0.0.1"},
        new_user[:dn],
        new_user[:attributes]
      )
    end
    
    # Delete LDAP user
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    #
    # @return [Hash] Returns a hash containing the result of the operation
    def delete_user(user)
      groups = get_user_groups(user)
      
      delete_user_from_groups(user, groups) if groups
      
      delete(
        {:name => "localuser", :ip => "127.0.0.1"},
        "cn=#{user['first']} #{user['last']},#{@config[:userdn]}"
      )
    end
    
    # Perform operation (:add, :delete) on user and a set of groups
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    # @param [Array] groups Groups to perform operation on
    #
    # @return [Hash] Returns a hash containing the result of the operation
    def user_groups_operation(user, groups, operation)
      params = {
        :first => user['first'],
        :last => user['last'],
        :username => user['username'],
        :uid => user['uid']
      }
      
      groups.each do |group|
        params[:groupname] = group
        group_op = JSON.parse(
          @config[:templates][:group].result(binding),
          :symbolize_names => true
        )
      
        group_op[:ops].each do |op|
          op[0] = operation
          op[1] = op[1].to_sym
        end
        
        ret = modify({:name => "localuser", :ip => "127.0.0.1"}, group_op[:dn], group_op[:ops])
      end
    end
    
    # Add user to LDAP groups
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    # @param [Array] groups
    #
    # @return [Hash] Returns a hash containing the result of the operation
    def add_user_to_groups(user, groups)
      user_groups_operation(user, groups, :add)
    end
    
    # Delete user from LDAP groups
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    # @param [Array] groups
    #
    # @return [Hash] Returns a hash containing the result of the operation
    def delete_user_from_groups(user, groups)
      user_groups_operation(user, groups, :delete)
    end
    
    # Get groups a user belongs to
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    # @param [Array] groups
    #
    # @return [Array] Returns an array of groups a user is a member of
    def get_user_groups(user)
      ldap_user = get_user(user)
      group_filter = Net::LDAP::Filter.eq(
        "member", "cn=#{ldap_user[:first]} #{ldap_user[:last]},#{@config[:userdn]}"
      )
      
      res = search(@config[:groupdn], group_filter)
      
      if (res[:message] != "Success")
        # tbd handle error
        return nil
      end
      
      if (res[:values] == [])
        return nil
      end
      
      groups = []
      
      res[:values].each do |group|
        groups << group.cn.first
      end
      
      return groups
    end
    
    # Get LDAP parameters of a user
    # 
    # @param [Hash] user User parameters - Firstname, Lastname, Username etc
    #
    # @return [Hash] Returns a hash of user parameters
    def get_user(user)
      user_filter = Net::LDAP::Filter.eq("uid", user['username'])
      res = search(@config[:userdn], user_filter)
      
      if (res[:message] != "Success")
        # tbd handle error
        return nil
      end
      
      if (res[:values] == [])
        return nil
      end
      
      user = {
        :username => res[:values].first.uid.first,
        :uid => res[:values].first.uidnumber.first,
        :gid => res[:values].first.gidnumber.first,
        :first => res[:values].first.givenname.first,
        :last => res[:values].first.sn.first
      }
      
      return user
    end
    
    # Check if a user exists in LDAP
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
  
    # Get a DES password hash
    #
    # @param [String] password Plain text password to be hashed
    # 
    # @return [String] Returns a DES password hash formatted for LDAP
    def crypt(password)
      characters = [ ("A" .. "Z").to_a, ("a" .. "z").to_a, (0 .. 9).to_a, ".", "/" ].flatten
      salt = ""
      1.upto(4) { |index| salt = [salt, characters[rand(characters.length)].to_s].join }
      encrypt = ["{CRYPT}", password.crypt(salt)].join
      return encrypt
    end
    
    # Get an MD5 password hash
    #
    # @param [String] password Plain text password to be hashed
    # 
    # @return [String] Returns an MD5 password hash formatted for LDAP
    def crypt3(password, salt = nil)
      characters = [ ("A" .. "Z").to_a, ("a" .. "z").to_a, (0 .. 9).to_a, ".", "/" ].flatten
      if salt.nil?
        salt = ""
        1.upto(8) { |index| salt = [salt, characters[rand(characters.length)].to_s].join }
      end
      encrypt = UnixCrypt::MD5.build(password, salt)
      return ["{CRYPT}", encrypt].join
    end
    
    # Get an LAN Manager password hash
    #
    # @param [String] password Plain text password to be hashed
    # 
    # @return [String] Returns an LAN Manager (LM) password hash formatted for LDAP
    def lm_hash(password)
      NTLM::Util.lm_v1_hash(password).unpack("H*")[0].upcase
    end
    
    # Get an NT Manager password hash
    #
    # @param [String] password Plain text password to be hashed
    # 
    # @return [String] Returns an NT Manager (NT) password hash formatted for LDAP
    def nt_hash(password)
      NTLM::Util.nt_v1_hash(password).unpack("H*")[0].upcase
    end
  
    # Change LDAP user password
    # 
    # @param [Hash] requestor An authenticated user who made the password change request
    # @param [String] dn LDAP DN for a user subject
    # @param [String] password New password in plain text
    #
    # @return [Hash] Returns a hash containing the result of the password change operation
    def set_password(requestor, dn, password)
      ops = [
        [:replace, :userpassword, [crypt(password)]]
      ]
      log("#{requestor[:name]} #{requestor[:ip]} operation replace password \"#{password}\" for #{dn}")
      ret = {
        :status => 1,
        :message => "Success",
        :values => ""
      }
      @ds.modify(:dn => dn, :operations => ops)
      ret = @ds.get_operation_result
      return ret
    end
  
    # Low level LDAP search operation
    # 
    # @param [String] base Base DN to be searched
    # @param [Net::LDAP::Filter] filter LDAP search filter
    # @param [String] attributes LDAP search attributes
    #
    # @return [Hash] Returns a hash containing the result of the search operation
    def search(base, filter = nil, attributes = nil)
      rows = []
    
      timeout_status = nil
      search_status = nil
      begin
        timeout_status = Timeout::timeout(60) do
          @ds.search(:base => base, :filter => filter, :attributes => attributes) do |entry|
            if ((!entry.nil?) && (entry[:cn] != []))
              rows << entry
            end 
          end
        
          search_status = @ds.get_operation_result
        end
      rescue Timeout::Error => te
        ret = {
          :status => 0,
          :message => "Connection to LDAP timed out",
          :values => nil
        }
        return ret
      rescue Exception => e
        pp ["exception", e]
      end
    
      if (search_status.code == 0)
        ret = {
          :status => 1,
          :message => "Success",
          :values => rows
        }
      else
        ret = {
          :status => 0,
          :message => "Net-LDAP Error #{search_status.code}: #{search_status.message}",
          :values => nil
        }
      end
    
      return ret
    end
  
  
    # Find the next available UID in the LDAP database
    # 
    # @param [String] base Base DN to be searched
    # @param [Hash] range Range of UIDs to search
    #
    # @return [Hash] Returns a hash containing the result of the search operation
    def find_uid(base, range)
      search_rows = search(base, nil, ["cn", "uidnumber"])
      if (search_rows[:status] == 0)
        return search_rows
      else
        uids = search_rows[:values]
        uids.map! { |entry| entry[:uidnumber].first.to_i }
        selected = uids.select { |entry| ((entry < range[:high]) && (entry > range[:low])) }
        ret = {
          :status => 1,
          :message => "Success",
          :values =>selected.max.succ
        }
        return ret
      end
    end
  
    # Low level add LDAP operation wrapper
    # 
    # @param [Hash] requestor An authenticated user who made the add request
    # @param [String] dn LDAP DN for a user subject
    # @param [String] attributes LDAP add operation attributes
    #
    # @return [Hash] Returns a hash containing the result of the add operation
    def add(requestor, dn, attributes)
      log("#{requestor[:name]} #{requestor[:ip]} added #{dn}")
      ret = {
        :status => 1,
        :message => "Success",
        :values => ""
      }
      @ds.add(:dn => dn, :attributes => attributes)
      ret = @ds.get_operation_result
      return ret
    end
  
    # Low level modify LDAP operation wrapper
    # 
    # @param [Hash] requestor An authenticated user who made the modify request
    # @param [String] dn LDAP DN for a user subject
    # @param [Array] ops An array of modify operations
    #
    # @return [Hash] Returns a hash containing the result of the modify operation
    def modify(requestor, dn, ops)
      ops.each do |op|
        #pp ["op", op]
        #log("#{requestor[:name]} #{requestor[:ip]} operation #{op[0]} #{op[1]} \"#{op[2].join(', ')}\" for #{dn}")
      end
      ret = {
        :status => 1,
        :message => "Success",
        :values => ""
      }
      @ds.modify(:dn => dn, :operations => ops)
      ret = @ds.get_operation_result
      return ret
    end
    
    # Low level delete LDAP wrapper
    # 
    # @param [Hash] requestor An authenticated user who made the modify request
    # @param [String] dn LDAP DN for a user subject
    #
    # @return [Hash] Returns a hash containing the result of the delete operation
    def delete(requestor, dn)
      log("#{requestor[:name]} #{requestor[:ip]} deleted #{dn}")
      
      ret = {
        :status => 1,
        :message => "Success",
        :values => ""
      }
      @ds.delete(:dn => dn)
      ret = @ds.get_operation_result
      return ret
    end
  end
end