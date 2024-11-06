require 'logger'
require 'socket'
require 'resolv'
require 'base64'
require 'fiber'
require 'net/smtp'

# A small and highly customizable ruby SMTP-Server.
module SmtpServer

  class Server

    def initialize(port: 2525)
      @port = port
      @connections = []
      @logger = Logger.new(STDOUT)
      @server = TCPServer.new(port)
    end

    def start
      @logger.info("SMTP Server starting on port: #{ @port }")
      loop do
        if @connections.size < 4
          client = @server.accept_nonblock(exception: false)
          if client
            fiber = Fiber.new { handle_client(client) }
            @connections << fiber
            fiber.resume
          end
        else
          @connections.each do | fiber |
            fiber.resume if fiber.alive?
          end
          @connections.reject! { | fiber | !fiber.alive? }
        end
      end
    end

    private

    def handle_client(client)
      @logger.info("Client connected: #{client} ")
      @logger.info("Client connected: #{client} - #{client.peeraddr[2]}")
      client.puts "220 Welcome to the SMTP server"
      loop do
        request = client.gets
        break if request.nil?
        @logger.info("Received request: #{request.chomp}")
        client.puts "250 OK"
      end
      client.close
      @logger.info("Client disconnected")
    end

  end

  # class for SmtpServer
  class Smtpd

    def initialize(ports: [2525])
      @ports = ports
      @servers = []
      @logger = Logger.new(STDOUT)
    end

    def start
      @ports.each do |port|
        server = Server.new(port: port)
        @servers << server
        Thread.new { server.start }
      end

      @logger.info("SMTP Servers started on ports: #{ @ports.join(', ') }")

      loop do
        @servers.each do |server|
          unless server_running?(server)
            @logger.error("Server on port #{server.instance_variable_get(:@port)} has stopped.")
          end
        end
        sleep 5
      end
    end

    private

    def server_running?(server)
      !server.instance_variable_get(:@server).closed?
    end

  end

end
