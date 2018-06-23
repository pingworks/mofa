require 'net/ssh'
require 'net/sftp'

class ProvisionCmd < MofaCmd
  attr_accessor :hostlist
  attr_accessor :runlist_map
  attr_accessor :attributes_map

  def initialize(token, cookbook)
    super(token, cookbook)
  end

  def prepare
    cookbook.prepare
  end

  def execute(sshport = 22)
    cookbook.execute

    hostlist.retrieve
    runlist_map.generate
    attributes_map.generate

    puts "Runlist Map: #{runlist_map.mp.inspect}"
    puts "Attributes Map: #{attributes_map.mp.inspect}"
    puts "Hostlist before runlist filtering: #{hostlist.list.inspect}"
    puts "Options: #{options.inspect}"

    hostlist.filter_by_runlist_map(runlist_map)

    puts "Hostlist after runlist filtering: #{hostlist.list.inspect}"

    exit_code = run_chef_solo_on_hosts(sshport)

    exit_code
  end

  def cleanup
    cookbook.cleanup
  end

  # FIXME
  # This Code is Copy'n'Pasted from the old mofa tooling. Only to make the MVP work in time!!
  # This needs to be refactored ASAP.

  def host_avail?(hostname)
    host_available = false
    puts "Pinging host #{hostname}..."
    exit_status = system("ping -q -c 1 #{hostname} >/dev/null 2>&1")
    if exit_status
      puts "  --> Host #{hostname} is available."
      host_available = true
    else
      puts "  --> Host #{hostname} is unavailable!"
    end
    host_available
  end

  def prepare_host(hostname, host_index, solo_dir)
    puts
    puts '----------------------------------------------------------------------'
    puts "Chef-Solo on Host #{hostname} (#{host_index}/#{hostlist.list.length})"
    puts '----------------------------------------------------------------------'
    Net::SSH.start(hostname, Mofa::Config.config['ssh_user'], keys: [Mofa::Config.config['ssh_keyfile']], port: Mofa::Config.config['ssh_port'], use_agent: false, verbose: :error) do |ssh|
      puts "Remotely creating solo_dir \"#{solo_dir}\" on host #{hostname}"
      # remotely create the temp folder
      out = ssh_exec!(ssh, "[ -d #{solo_dir} ] || mkdir #{solo_dir}")
      puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0

      # remotely create a data_bags folder structure on the target host
      if File.directory?("#{cookbook.source_dir}/data_bags")
        Dir.entries("#{cookbook.source_dir}/data_bags").select { |f| !f.match(/^\.\.?$/) }.each do |data_bag|
          puts "Remotely creating data_bags dir \"#{solo_dir}/data_bags/#{data_bag}\""
          out = ssh_exec!(ssh, "[ -d #{solo_dir}/data_bags/#{data_bag} ] || mkdir -p #{solo_dir}/data_bags/#{data_bag}")
          puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
        end
      end
    end
  end

  def create_solo_rb(sftp, hostname, solo_dir)
    puts "Remotely creating \"#{solo_dir}/solo.rb\" on #{hostname}..."
    sftp.file.open("#{solo_dir}/solo.rb", 'w') do |file|
      solo_rb = <<-"EOF"
    cookbook_path [ "#{solo_dir}/cookbooks" ]
    data_bag_path "#{solo_dir}/data_bags"
    verify_api_cert true
      EOF

      file.write(solo_rb)
    end
  end
# log_level :info
# log_location "#{solo_dir}/log"

  def create_node_json(sftp, hostname, solo_dir, attributes_map)
    puts "Remotely creating \"#{solo_dir}/node.json\" on #{hostname}..."
    node_json = {}
    node_json.store('run_list', runlist_map.mp[hostname])
    attributes_map.mp[hostname].each do |key, value|
      node_json.store(key, value)
    end

    sftp.file.open("#{solo_dir}/node.json", 'w') do |file|
      file.write(JSON.pretty_generate(node_json))
    end
  end

  def create_data_bags(sftp, hostname, solo_dir)
    puts "Remotely creating data_bags items on #{hostname}..."
    if File.directory?("#{cookbook.source_dir}/data_bags")
      Dir.entries("#{cookbook.source_dir}/data_bags/").each do |data_bag|
        next if data_bag =~ /^\.\.?$/
        puts "Found data_bag #{data_bag}... "
        Dir.entries("#{cookbook.source_dir}/data_bags/#{data_bag}").select { |f| f.match(/\.json$/) }.each do |data_bag_item|
          puts "Uploading data_bag_item #{data_bag_item}... "
          sftp.upload!("#{cookbook.source_dir}/data_bags/#{data_bag}/#{data_bag_item}", "#{solo_dir}/data_bags/#{data_bag}/#{data_bag_item}")
          puts 'OK.'
        end
      end
    end
  end

  def run_chef_solo_on_hosts(sshport = Mofa::Config.config['ssh_port'])
    time = Time.new
    # Create a temp working dir on the target host
    solo_dir = '/var/tmp/' + time.strftime('%Y-%m-%d_%H%M%S')
    puts
    puts 'Chef-Solo Run started at ' + time.strftime('%Y-%m-%d %H:%M:%S')
    puts "Will use ssh_user #{Mofa::Config.config['ssh_user']}, ssh_port #{sshport} and ssh_key_file #{Mofa::Config.config['ssh_keyfile']}"
    at_least_one_chef_solo_run_failed = false
    chef_solo_runs = {}
    host_index = 0
    hostlist.list.each do |hostname|
      host_index += 1
      chef_solo_runs.store(hostname, {})

      unless options.key?('ignore_ping') && options[:ignore_ping] == true
        unless host_avail?(hostname)
          chef_solo_runs[hostname].store('status', 'UNAVAIL')
          chef_solo_runs[hostname].store('status_msg', "Host #{hostname} unreachable.")
          at_least_one_chef_solo_run_failed = true
          next
        end
      end

      prepare_host(hostname, host_index, solo_dir)

      Net::SFTP.start(hostname, Mofa::Config.config['ssh_user'], keys: [Mofa::Config.config['ssh_keyfile']], port: sshport, use_agent: false, verbose: :error) do |sftp|
        # remotely creating solo.rb
        create_solo_rb(sftp, hostname, solo_dir)

        # remotely creating node.json
        create_node_json(sftp, hostname, solo_dir, attributes_map)

        # remotely create data_bag items
        create_data_bags(sftp, hostname, solo_dir)

        puts "Uploading Package #{cookbook.pkg_name}... "
        sftp.upload!("#{cookbook.pkg_dir}/#{cookbook.pkg_name}", "#{solo_dir}/#{cookbook.pkg_name}")
        puts 'OK.'

        File.open("#{cookbook.pkg_dir}/log", 'w') do |log_file|
          # Do it -> Execute the chef-solo run!
          begin
            begin
              Net::SSH.start(hostname, Mofa::Config.config['ssh_user'], keys: [Mofa::Config.config['ssh_keyfile']], port: sshport, use_agent: false, verbose: :error) do |ssh|
                puts "Remotely unpacking Cookbook Package #{cookbook.pkg_name}... "
                ssh.exec!("cd #{solo_dir}; tar xvfz #{cookbook.pkg_name}") do |_ch, _stream, line|
                  puts line if Mofa::CLI.option_debug
                  log_file.write(line) if Mofa::CLI.option_debug
                end
                puts 'OK.'
              end
            rescue StandardError => e
              status_msg = "ERROR: Unpacking cookbook archive on remote host #{hostname} failed (#{e.message})!"
              chef_solo_runs[hostname].store('status', 'FAIL')
              chef_solo_runs[hostname].store('status_msg', status_msg)
              puts status_msg
              log_file.write(status_msg)
              raise e
            end
            begin
              Net::SSH.start(hostname, Mofa::Config.config['ssh_user'], keys: [Mofa::Config.config['ssh_keyfile']], port: sshport, use_agent: false, verbose: :error) do |ssh|
                puts "Remotely running chef-solo -c #{solo_dir}/solo.rb -j #{solo_dir}/node.json"
                chef_run_exit_code = 0
                ssh.exec!("sudo chef-solo -c #{solo_dir}/solo.rb -j #{solo_dir}/node.json") do |_ch, _stream, line|
                  puts line if Mofa::CLI.option_verbose || Mofa::CLI.option_debug
                  log_file.write(line)
                  chef_run_exit_code = 1 if line =~ /Chef run process exited unsuccessfully/
                end
                raise 'Chef run process exited unsuccessfully' if chef_run_exit_code != 0
                chef_solo_runs[hostname].store('status', 'SUCCESS')
                chef_solo_runs[hostname].store('status_msg', '')
                puts 'Chef-solo run was a SUCCESS!'
                log_file.write('chef-solo run: SUCCESS')
              end
            rescue StandardError => e
              status_msg = "ERROR: Chef-solo run on #{hostname} FAILED! (#{e.message})"
              chef_solo_runs[hostname].store('status', 'FAIL')
              chef_solo_runs[hostname].store('status_msg', status_msg)
              puts status_msg
              log_file.write(status_msg)
              raise e
            end
          rescue StandardError => e
            log_file.write('chef-solo run: FAIL')
            puts "ERRORS detected while provisioning #{hostname} (#{e.message})."
          end
          Net::SSH.start(hostname, Mofa::Config.config['ssh_user'], keys: [Mofa::Config.config['ssh_keyfile']], port: sshport, use_agent: false, verbose: :error) do |ssh|
            snapshot_or_release = cookbook.is_a?(SourceCookbook) ? 'snapshot' : 'release'
            out = ssh_exec!(ssh, "sudo chown -R #{Mofa::Config.config['ssh_user']}.#{Mofa::Config.config['ssh_user']} #{solo_dir}")
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
            out = ssh_exec!(ssh, '[ -d /var/lib/mofa ] || sudo mkdir /var/lib/mofa')
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
            out = ssh_exec!(ssh, "echo #{cookbook.name} | sudo tee /var/lib/mofa/last_cookbook_name")
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
            out = ssh_exec!(ssh, "echo '#{snapshot_or_release}' | sudo tee /var/lib/mofa/last_cookbook_snapshot_or_release")
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
            out = ssh_exec!(ssh, "echo #{cookbook.version} | sudo tee /var/lib/mofa/last_cookbook_version")
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
            out = ssh_exec!(ssh, "echo #{chef_solo_runs[hostname]['status']} | sudo tee /var/lib/mofa/last_status")
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
            out = ssh_exec!(ssh, "date '+%Y-%m-%d %H:%M:%S' | sudo tee /var/lib/mofa/last_timestamp")
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
            out = ssh_exec!(ssh, "echo '#{solo_dir}/log' | sudo tee /var/lib/mofa/last_log")
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
            out = ssh_exec!(ssh, "echo $(date '+%Y-%m-%d %H:%M:%S')': #{cookbook.name}@#{cookbook.version} (#{chef_solo_runs[hostname]['status']})' | sudo tee -a /var/lib/mofa/history")
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
            out = ssh_exec!(ssh, "sudo find #{solo_dir} -type d | xargs chmod 700")
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
            out = ssh_exec!(ssh, "sudo find #{solo_dir} -type f | xargs chmod 600")
            puts "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
          end
        end
        at_least_one_chef_solo_run_failed = true unless chef_solo_runs[hostname]['status'] == 'SUCCESS'
        sftp.upload!("#{cookbook.pkg_dir}/log", "#{solo_dir}/log")
      end
    end
    # ------- print out report
    puts
    puts '----------------------------------------------------------------------'
    puts 'Chef-Solo Run REPORT'
    puts '----------------------------------------------------------------------'
    puts "Chef-Solo has been run on #{chef_solo_runs.keys.length} hosts."

    chef_solo_runs.each do |hostname, content|
      status_msg = ''
      status_msg = "(#{content['status_msg']})" if content['status'] == 'FAIL'
      puts "#{content['status']}: #{hostname} #{status_msg}"
    end

    exit_code = at_least_one_chef_solo_run_failed ? 1 : 0
    puts "Exiting with exit code #{exit_code}."

    if exit_code != 0
      raise Thor::Error, "Chef client exited with non zero exit code: #{exit_code}"
    end
    exit_code
  end
end
