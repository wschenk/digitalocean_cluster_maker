#!/usr/bin/env ruby -KU

require 'JSON'

class Cluster
  def initialize( count = 3 )
    @count = count.to_i
    get_binaries
  end

  def info
    droplets.each do |droplet|
      printf "%20s %20s %20s\n", droplet[:name], droplet[:public_ip], droplet[:private_ip]
    end

    if droplets.length == 0
      puts "No running machines"
    else
      ssh droplets.first, "fleetctl list-machines"
    end
  end

  def reload_droploads
    system( "rm -f tmp/machines.json")
    @droplets = nil
  end

  def droplets
    return @droplets if @droplets

    @droplets = []

    system( "mkdir -p tmp")
    if !File.exist?( 'tmp/machines.json' )|| (Time.now - File.stat('tmp/machines.json').mtime) > 300
      puts "Download"
      system( "curl -X GET -H \"Content-Type: application/json\" -H \"Authorization: Bearer #{ENV['TOKEN']}\" \"https://api.digitalocean.com/v2/droplets\" > tmp/machines.json")
    end

    json = JSON.parse File.read( "tmp/machines.json" )

    json['droplets'].each do |x|
      if x['name'] =~ /coreos/
        public_ip = nil
        private_ip = nil

        x['networks']['v4'].each do |ip|
          public_ip  = ip['ip_address'] if ip['type'] == 'public'
          private_ip = ip['ip_address'] if ip['type'] == 'private'
        end

        @droplets << { name: x['name'], public_ip: public_ip, private_ip: private_ip, id: x['id'] }
      end
    end

    @droplets
  end

  def shutdown
    require 'pp'
    droplets.each do |droplet|
      # pp droplet
      puts "Destroying #{droplet[:name]}"
      system "curl -X DELETE -H \"Content-Type: application/json\" -H \"Authorization: Bearer #{ENV['TOKEN']}\" \"https://api.digitalocean.com/v2/droplets/#{droplet[:id]}\""
    end

    system "rm -rf tmp"
  end

  def ensure_droplets
    unless File.exist? 'tmp/cloud-config.yml'
      system "mkdir -p tmp"
      url = `curl https://discovery.etcd.io/new`
      data = File.read 'templates/cloud-config.yml'
      output = data.gsub( /https:\/\/discovery.etcd.io\/new/, url)
      File.open( "tmp/cloud-config.yml", "w" ) { |out| out.puts output }
      # exit
    end

    if droplets.length < @count
      puts "droplets.length #{ droplets.length }"
      reload_droploads
      puts "Starting droplets..."
      l = droplets.length
      while l < @count
        l += 1
        name = "coreos-#{l}"
        puts "Creating #{name}"
        system( "bash makecoreos.sh #{name}" )
        puts
      end

      puts
      reload_droploads
      system( "open https://cloud.digitalocean.com/droplets")
      puts "Now wait until the machine is up before running start again"
      exit
    end
  end

  def ssh droplet, string
    puts "Running ssh core@#{droplet[:public_ip]} #{string}"
    system( "ssh core@#{droplet[:public_ip]} #{string}")
  end

  def create_pem
    system "mkdir -p tmp"
    system "./bin/cfssl gencert -initca templates/ca-csr.json | ./bin/cfssljson -bare ca -"
    system "mv ca*pem tmp"
  end

  def copy_pem
    if Dir.glob( "tmp/ca*pem").length == 0
      create_pem
    end

    droplets.each do |droplet|
      machine_template = File.read 'templates/machine_template.json'

      machine = machine_template.gsub( /machine_name/, droplet[:name] ).gsub( /machine_private_ip/, droplet[:private_ip] )
      File.open( "tmp/#{droplet[:name]}.json", "w" ) { |out| out.puts machine }

      system( "./bin/cfssl gencert -ca=tmp/ca.pem -ca-key=tmp/ca-key.pem -config=templates/ca-config.json -profile=client-server tmp/#{droplet[:name]}.json | ./bin/cfssljson -bare coreos" )
      puts "Copying to #{droplet[:name]}"
      system( "scp tmp/ca.pem coreos-key.pem coreos.pem core@#{droplet[:public_ip]}:" )
      system( "rm -f coreos-key.pem coreos.pem coreos.csr")
      system( "ssh core@#{droplet[:public_ip]} chmod 0644 /home/core/coreos-key.pem")
    end
  end

  def copy_iptable_rules
    iptables_template = File.read 'templates/iptable.rules'

    rules = droplets.collect { |x| "-A INPUT -i eth1 -p tcp -s #{x[:private_ip]} -j ACCEPT" }.join( "\n" )
    iptables = iptables_template.gsub( /_private_ip_line_/, rules )

    File.open( "tmp/rules-save", "w" ) { |out| out.puts iptables }

    droplets.each do |droplet|
      puts "Copying to #{droplet[:name]}"
      system( "scp tmp/rules-save core@#{droplet[:public_ip]}:")
      system( "ssh core@#{droplet[:public_ip]} sudo cp rules-save /var/lib/iptables")
    end
  end

  def get_binaries
    system( "mkdir -p bin")
    unless File.exist? './bin/cfssl'
      puts "Downloading cfssl"
      system "curl -s -L -o ./bin/cfssl https://pkg.cfssl.org/R1.1/cfssl_darwin-amd64"
      system "chmod +x ./bin/cfssl"
    end

    unless File.exist? './bin/cfssljson'
      puts "Download cfssljson"
      system "curl -s -L -o ./bin/cfssljson https://pkg.cfssl.org/R1.1/cfssljson_darwin-amd64"
      system "chmod +x ./bin/cfssljson"
    end
  end

  def restart
    droplets.each do |droplet|
      ssh droplet, 'sudo reboot'
    end
  end
end

c = Cluster.new ENV['CLUSTER_SIZE']

case ARGV[0]
when 'restart'
  c.restart
when 'start'
  c.ensure_droplets
  c.copy_iptable_rules
  c.copy_pem
when 'ssh', 'ssh1'
  system( "ssh core@#{c.droplets.first[:public_ip]}" )
when 'ssh2'
  system( "ssh core@#{c.droplets[1][:public_ip]}" )
when 'ssh3'
  system( "ssh core@#{c.droplets[2][:public_ip]}" )
when 'shutdown'
  c.shutdown
else
  c.info
end