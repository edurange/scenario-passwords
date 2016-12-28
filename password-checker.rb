require 'socket'
require 'fileutils'

class LogPassGen
  @home_dir = '/home'
  @template_data_path = 'templatedata'
  @characters = ["Takako", "Kenna", "Ike"]

  @var_holders = [
    "_catchphrase_",
    "_college_",
    "_elementaryschool_",
    "_exgirlfriend_",
    "_favteacher_",
    "_franchise_",
    "_highschool_",
    "_hometown_",
    "_mascot_",
    "_momname_",
    "_petname_",
    "_streetname_"
  ]

  def self.create user_name, answersockpath
    @user_name = user_name
    @answersockpath = answersockpath
    @user_dir = "#{@home_dir}/#{user_name}"
    return nil, nil if not File.exists? @user_dir

    @passwords = {}
    @chat_log = File.open("#{@template_data_path}/chatlog.txt", "r").read()
    @chat_log = @chat_log.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')

    self.set_time
    self.set_characters
    self.get_random_vars
    self.create_simple_vars
    self.create_passwords_character_0
    self.write_log_file
    self.create_user_answer_templates
 
    return @passwords, @chat_log
  end

  def self.get_random_vars
    @vars = {}
    @var_holders.each do |var_holder|
      arr = File.open("#{@template_data_path}/#{var_holder}.txt", "r").read().split("\n")
      var = arr[rand(arr.length)]
      @vars[var_holder] = var
      @chat_log.gsub!(var_holder, var)
    end
  end

  def self.set_time
    @chat_log.gsub!("_date_", Time.at(rand * Time.now.to_i).strftime("%m-%d") + "-" + Time.now.strftime("%y"))
  end

  def self.set_characters
    @chat_log.gsub!("_character1_", @characters[0])
    @chat_log.gsub!("_character2_", @characters[1])
    @chat_log.gsub!("_character3_", @characters[2])
  end

  def self.create_simple_vars
    @var_simples = {}

    @vars.each do |key, val|
      @var_simples[key] = val.downcase.gsub(" ", "")
    end

    @var_simples['_college_'] = @vars['_college_'].split(" ")[0].downcase
    @var_simples['_favteacher_'] = @var_simples['_favteacher_'][3..-1]
  end

  def self.create_passwords_character_0
    charname = @characters[0]
    @passwords[charname] = {}
    c = @passwords[charname]

    c[@var_simples['_highschool_']] = 1
    c[@var_simples['_catchphrase_']] = 1
    c[@var_simples['_hometown_']] = 1
    c[@var_simples['_franchise_']] = 1
    c[@var_simples['_elementaryschool_']] = 1
    c[@var_simples['_favteacher_']] = 1
  end

  def self.write_log_file
    path = "#{@user_dir}/chatlog"
    File.open(path, "w") { |f| f.write(@chat_log) }
    FileUtils.chown @user_name, @user_name, path
  end

  def self.create_user_answer_templates
    answer_template_path = "#{@user_dir}/answer.rb"
    ans = File.open('answer.rb', 'r').read.gsub("SOCKPATH", @answersockpath)
    File.open(answer_template_path, 'w') { |f| f.write(ans) }
    #FileUtils.cp 'answer.rb', answer_template_path
    FileUtils.chown @user_name, @user_name, answer_template_path
  end
end

class AnswerChecker
  class UserData
    @@attempts = 0
    @@points = 0
    @@answered = {}

    def initialize(uid, passwords, chatlog, logpath)
      @@uid = uid
      @@username = `getent passwd #{@@uid}`.split(':')[0]
      @@passwords = passwords
      @@chatlog = chatlog
      create_log_files logpath
    end

    def create_log_files(logpath)

      @@user_log_path = "#{logpath}/#{@@username}"
      if not File.exists? @@user_log_path
        FileUtils.mkdir @@user_log_path
      end

      @@attempts_file = File.open("#{@@user_log_path}/attempts", "w")
      @@attempts_file.sync = true
      @@attempts_file.write 0

      @@points_file = File.open("#{@@user_log_path}/points", "w")
      @@points_file.sync = true
      @@points_file.write 0

      @@answers_file = File.open("#{@@user_log_path}/answers", "w")
      @@answers_file.sync = true

      chatlog_file = File.open("#{@@user_log_path}/chatlog", "w")
      chatlog_file.sync = true
      chatlog_file.write(@@chatlog)

      passwords_file = File.open("#{@@user_log_path}/passwords", "w")
      passwords_file.sync = true
      @@passwords.each do |character, passhash|
        passhash.each do |password, points|
          passwords_file.write("#{character}:#{password}:#{points}\n")
        end
      end
    end

    def inc_attempt
      @@attempts += 1
      @@attempts_file.seek 0
      @@attempts_file.write(@@attempts)
    end

    def add_correct(character, password, points)
      if not @@answered.has_key?(character)
        @@answered[character] = {}
      end
      if not @@answered[character].has_key?(password)
        @@answered[character][password] = points

        @@answers_file.seek 0
        @@answered.each do |character, passhash|
          passhash.each do |password, points|
            @@answers_file.write("#{character}:#{password}\n")
          end
        end

        @@points += 1
        @@points_file.seek 0
        @@points_file.write(@@points)
      end
    end
  end

  @@data_dir = './'
  @@sock_register_path = "#{@@data_dir}/register.sock"
  @@sock_answer_path = "/var/run/edurange-password-answer.sock"
  @@userdata_path = "#{@@data_dir}/userdata"
  @@log_path = "#{@@data_dir}/log"

  @@passwords = {}
  @@user_ids = {}
  @@user_data = {}
  @@rate = 1

  def initialize
    File.open("#{@@data_dir}/pid", "w") { |f| f.write(Process.pid) }

    if not File.exists? @@data_dir
      FileUtils.mkpath @@data_dir
    end
    # FileUtils.chown 'edurange-password', 'edurange-password', @@data_dir

    FileUtils.rm @@sock_register_path if File.exists? @@sock_register_path
    FileUtils.rm @@sock_answer_path if File.exists? @@sock_answer_path

    FileUtils.mkdir @@userdata_path if not File.exists? @@userdata_path

    @@runlog = File.open(@@log_path, "w")
    @@runlog.sync = true
    @@runlog.write "starting:#{Time.now}\n"    

    @@regserv = UNIXServer.new(@@sock_register_path)
    FileUtils.chmod 0600, @@sock_register_path

    Thread.new do 
      begin
        register_loop
      rescue => e
        @@runlog.write("register:#{e.message} #{e.class} #{e.backtrace}\n")
      end
    end
    begin
      answer_loop
    rescue => e
      @@runlog.write("answer:#{e.message} #{e.class} #{e.backtrace}\n")
    end
  end

  def register_loop
   @@runlog.write "register: started\n"
    loop do
      client = @@regserv.accept
      
      if (input = client.gets) != nil
        input = input.chomp
        p, c = LogPassGen.create(input, @@sock_answer_path)
        if p != nil
          uid = `getent passwd #{input}`.split(':')[2].to_i
          @@passwords[uid.to_i] = p
          if not @@user_data.has_key?(uid)
            @@user_data[uid] = UserData.new(uid, p, c, @@userdata_path)
            @@runlog.write "register: registered user '#{input}'\n"
          else
            @@runlog.write "register:user already exists\n"
          end
        else
          @@runlog.write("register: failed to register '#{input}'\n")
        end
      end

      client.close
    end
  end

  def answer_loop
    serv = UNIXServer.new(@@sock_answer_path)
    FileUtils.chmod 0666, @@sock_answer_path
    loop do
      Thread.start(serv.accept) do |client|

        # get userid
        userid = client.getpeereid[0]
        @@runlog.write "answer: #{userid} connected\n"
        # only allow registered users to connect
        if not @@user_data.has_key?(userid)
          @@runlog.write "answer: #{userid} user not registered\n"
          client.puts "not-registered"
          client.close
          next
        end

        # only allow one connection per user
        if @@user_ids.has_key? userid
          @@runlog.write "answer: #{userid} already has connection\n" 
          client.close
          next
        end
        @@user_ids[userid] = Time.now

        # get input
        until (input = client.gets) == nil
          
          @@runlog.write "answer: #{userid} got #{input}"

          # split input
          split = input.split(':')
          if split.size < 2
            @@runlog.write "answer: #{userid} bad format\n"
            client.puts 0
            next
          end

          name = split[0].strip
          password = split[1].strip

          # check for correct answer
          if @@passwords.has_key?(userid) && @@passwords[userid].has_key?(name) && @@passwords[userid][name].has_key?(password)
            client.puts @@passwords[userid][name][password]
            @@user_data[userid].add_correct(name, password, @@passwords[userid][name][password])
            @@runlog.write "answer: #{userid} correct\n" 
          else
            @@runlog.write "answer: #{userid} wrong\n"
            client.puts 0
          end

          # increment user attempts
          @@user_data[userid].inc_attempt

          # rate limit requests
          t1 = Time.now
          tdiff = t1 - @@user_ids[userid]
          if tdiff < @@rate
            sleep @@rate - tdiff
          end
          @@user_ids[userid] = Time.now
        end

        # remove user
        @@runlog.write "answer: #{userid} disconnected\n"
        @@user_ids.delete userid
        client.close
      end
    end
  end
end

AnswerChecker.new
