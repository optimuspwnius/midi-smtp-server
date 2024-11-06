require 'logger'
require 'socket'
require 'resolv'
require 'base64'
require 'async'
#require 'async/io'
require 'net/smtp'

# A small and highly customizable ruby SMTP-Server.
module SmtpServer

  class Server

    def initialize(port: 2525)
      @port = port
      @logger = Logger.new(STDOUT)
    end

    def start
      @logger.info("SMTP Server starting on port: #{ @port }")

      Async do |task|
        endpoint = Async::IO::Endpoint.tcp('0.0.0.0', @port)
        endpoint.bind do |server|
          @logger.info("Listening on port #{ @port }")
          loop do
            client = server.accept
            task.async do
              handle_client(client)
            end
          end
        end
      end
    end

    private

    def handle_client(client)
      @logger.info("Client connected: #{client.remote_address.ip_address}")
      client.write "220 Welcome to the SMTP server\r\n"
      loop do
        request = client.readpartial(1024)
        break if request.nil?
        @logger.info("Received request: #{request.chomp}")

        client.write "250 OK\r\n"
      end
      client.close
      @logger.info("Client disconnected")
    end

  end

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
      # This method should be updated to check the status of the async server
      true
    end

  end

end
