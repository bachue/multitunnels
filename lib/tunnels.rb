require 'tunnels/version'
require 'tunnels/parser'
require 'uri'
require 'eventmachine'

# most of code is from [thin-glazed](https://github.com/freelancing-god/thin-glazed).
# Copyright © 2012, Thin::Glazed was a Rails Camp New Zealand project, and is developed and maintained by Pat Allan. It is released under the open MIT Licence.

class ClientNotFound < StandardError; end

module HTTPS
  def post_init
    start_tls
  end
end

module Tunnels
  def self.run!(params)
    maps = parse_params params

    maps.each do |from, to|
      puts "#{from[0]}://#{from[1]}:#{from[2]} --(--)--> #{to[0]}://#{to[1]}:#{to[2]}"
    end

    maps = group_params maps

    EventMachine.run do
      servers = {}
      maps.each do |from, map|
        scheme, port = from
        servers[from] ||= case scheme
                          when :https
                            EventMachine.start_server('127.0.0.1', port, HttpsProxy, map)
                          when :http
                            EventMachine.start_server('127.0.0.1', port, HttpProxy, map)
                          end
      end
      puts "Ready :)"
    end
  rescue RuntimeError => e
    STDERR.puts e.message
    STDERR.puts "Maybe you should run on `sudo`"
  end

  def self.help
    <<-HELP
Usage:
    multitunnels [from to] [from2 to2] ...

Examples:
    multitunnels 443 3000
    multitunnels localhost:443 localhost:3000
    multitunnels https://:443 http://:3000
    multitunnels https://localhost:443 http://localhost:3000

    HELP
  end

  private
    def self.parse_params params = []
      params = ['443', '80'] if params.empty?
      maps = split_params params
      maps.inject({}) do |h, (from, to)|
        h.merge parse_host_str(from) => parse_host_str(to)
      end
    end

    def self.group_params params = {}
      params.inject({}) do |h, (from, to)|
        h[[from[0], from[2]]] ||= {}
        h[[from[0], from[2]]].merge! from => to
        h
      end
    end

    def self.split_params params = []
      Hash[*params]
    end

    def self.parse_host_str str
      raise ArgumentError if str.empty?
      if str =~ /^:?(\d+)$/
        [get_scheme($1), '127.0.0.1', $1.to_i]
      elsif str =~ /^(\w+):\/\/:(\d+)$/
        [$1.to_sym, '127.0.0.1', $2.to_i]
      elsif str =~ /:\/\//
        uri = URI str
        [uri.scheme.to_sym, uri.host, uri.port]
      else
        parts = str.split(':')
        raise ArgumentError if parts.size != 2
        [get_scheme(parts[1]), parts[0], parts[1].to_i]
      end
    end

    def self.get_scheme port
      port.to_i == 443 ? :https : :http
    end

  class HttpClient < EventMachine::Connection
    attr_reader :proxy, :to_host, :to_port

    def initialize(proxy, from_host, from_port, to_host, to_port)
      @proxy     = proxy
      @connected = EventMachine::DefaultDeferrable.new
      @from_host, @from_port, @to_host, @to_port = from_host, from_port, to_host, to_port
    end

    def connection_completed
      @connected.succeed
    end

    def receive_data(data)
      proxy.relay_from_client(data)
    end

    def send(data)
      @connected.callback { send_data data }
    end

    def unbind
      proxy.unbind_client @from_host, @from_port
    end
  end

  class HttpsClient < HttpClient
    include HTTPS
  end

  class HttpProxy < EventMachine::Connection
    def initialize(map)
      map.each do |from, to|
        book_client from[1], from[2], to[0], to[1], to[2]
      end
    end

    def receive_data(data)
      parser << data unless data.nil?
    end

    def send data
      client, connection_close = nil, nil

      data.sub!(/\r\nHost:\s*(.+?)\s*\r\n/i) do
        host, port = $1.split(':') if $1
        client = client host, port
        "\r\nHost: #{client.to_host}:#{client.to_port}\r\n"
      end

      raise ClientNotFound.new "HTTP Header `Host' is required in HTTP/1.1" unless client

      data.sub!(/\r\nConnection:(.+?)\r\n/i) do
        connection_close = true
        "\r\nConnection: close\r\n"
      end

      unless connection_close
        data.sub!(/\r\n\r\n/, "\r\nConnection: close\r\n\r\n")
      end

      client.send_data data
    rescue ClientNotFound => e
      STDERR.puts e.message
    end

    def relay_from_client(data)
      send_data data unless data.nil?
    end

    def unbind
      close_all_connections
    end

    def unbind_client host, port
      close_connection_after_writing
      clear_client host, port.to_i
    end

    private
      def book_client from_host, from_port, to_scheme, to_host, to_port
        from_port, to_port = from_port.to_i, to_port.to_i
        @clients ||= Hash.new {|h, k| h[k] = {} }
        @clients[from_host][from_port] = {:from_host => from_host, :from_port => from_port, :to_scheme => to_scheme, :to_host => to_host, :to_port => to_port}
      end

      def client_type scheme
        case scheme
        when :http  then HttpClient
        when :https then HttpsClient
        else
          raise ClientNotFound.new "Cannot support scheme: #{scheme}"
        end
      end

      def make_client_for client_info
        client =
          EventMachine.connect  client_info[:to_host],
                                client_info[:to_port],
                                client_type(client_info[:to_scheme]),
                                self,
                                client_info[:from_host],
                                client_info[:from_port],
                                client_info[:to_host],
                                client_info[:to_port]
        @clients[client_info[:from_host]][client_info[:from_port]][:client] = client
        client
      rescue
        puts $!.message
        puts $@.join("\n")
      end

      def client host, port
        port = port.to_i
        info =  search_client_by_host_and_port(host, port) ||
                search_client_by_host(host) ||
                raise(ClientNotFound.new "Cannot find a client for #{host}:#{port}")
        info[:client] || make_client_for(info)
      end

      def search_client_by_host_and_port host, port
        @clients[host][port] ||
        @clients['localhost'][port] ||
        @clients['127.0.0.1'][port] ||
        @clients['0.0.0.0'][port]
      end

      def search_client_by_host host
        @clients[host].values.first ||
        @clients['localhost'].values.first ||
        @clients['127.0.0.1'].values.first ||
        @clients['0.0.0.0'].values.first
      end

      def clear_client host, port
        info = @clients[host][port.to_i]
        info.delete :client if info
      end

      def close_all_connections
        @clients.each do |_, host|
          host.each do |_, info|
            info[:client].close_connection if info[:client]
            info.delete :client
          end
        end
      end

      def parser
        Thread.current['parser'] ||= begin
          parser = Parser.new
          parser.on_complete do |data|
            send data
          end
          parser
        end
      end
  end

  class HttpsProxy < HttpProxy
    include HTTPS

    def relay_from_client(data)
      super
      @x_forwarded_proto_header_inserted = false
    end

    def receive_data(data)
      if !@x_forwarded_proto_header_inserted && data =~ /\r\n\r\n/
        super data.gsub(/\r\n\r\n/, "\r\nX_FORWARDED_PROTO: https\r\n\r\n")
        @x_forwarded_proto_header_inserted = true
      else
        super
      end
    end
  end
end
