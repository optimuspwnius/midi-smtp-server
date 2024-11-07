require 'logger'
require 'socket'
require 'resolv'
require 'base64'
require 'async'
require 'async/semaphore'
require 'async/io'
require 'net/smtp'

# A small and highly customizable ruby SMTP-Server.
module SmtpServer

  class Server

    def initialize(port: 2525)
      @port = port
      @logger = Logger.new(STDOUT)
      @semaphore = Async::Semaphore.new(4) # Limit to 4 concurrent connections
    end

    def start
      @logger.info("SMTP Server starting on port: #{ @port }")

      @endpoint = Async::IO::Endpoint.tcp('127.0.0.1', @port)

      @logger.info("Listening on port #{ @port }")

      Async do | task |
        @endpoint.accept do | client |
          @semaphore.async do
            handle_client(client)
          end
        end
      end
    end

    private

    def handle_client(client)
      @logger.info("Client connected: #{client}")
      client.write "220 Welcome to the SMTP server\r\n"
      buffer = ""
      loop do
        data = client.readpartial(1024)

        break if data.nil?

        buffer << data
        @logger.info("Received data: #{data.chomp}")

        # Check for QUIT command
        if buffer.include?("QUIT\r\n")
          @logger.info("QUIT command received")
          client.write "221 Bye\r\n"
          break
        end

        # Check for end-of-message indicators
        if buffer.include?("\r\n.\r\n")
          @logger.info("End of message received")
          client.write "250 OK\r\n"
          buffer.clear
        end
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
      @logger.info("SMTP Servers starting on ports: #{ @ports.join(', ') }")
      @ports.each do | port |
        server = Server.new(port: port)
        @servers << server
        Thread.new { server.start }
      end

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
