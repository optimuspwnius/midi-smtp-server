require 'logger'
require 'socket'
require 'resolv'
require 'base64'
require 'fiber'
require 'net/smtp'

# A small and highly customizable ruby SMTP-Server.
module SmtpServer

  # class for SmtpServer
  class Smtpd

    def initialize(ports: [2525])
      @ports       = ports
      @servers     = @ports.map { | port | TCPServer.new(port) }
      @connections = []
      @logger      = Logger.new(STDOUT)
    end

    public

    def start
      @logger.info("SMTP Server starting on ports: #{ ports.join(', ') }")
      loop do
        @servers.each do | server |
          if @connections.size < 4
            client = server.accept_nonblock(exception: false)
            if client
              fiber = Fiber.new { handle_client(client) }
              @connections << fiber
              fiber.resume
            end
          else
            @connections.each do |fiber|
              fiber.resume if fiber.alive?
            end
            @connections.reject! { |fiber| !fiber.alive? }
          end
        end
      end
    end

    private

    def handle_client(client)
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

end
