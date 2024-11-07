require 'logger'
require 'socket'
require 'resolv'
require 'base64'
require 'async'
require 'async/semaphore'
require 'async/io'
require 'net/smtp'

module SmtpServer

  class Daemon

    def initialize(ports: [2525])
      @shutdown = false
      @servers  = []
      @logger   = Logger.new(STDOUT)
      @ports    = ports
    end

    def start
      @logger.info("SMTP Servers starting on ports: #{ @ports.join(', ') }")

      @servers = @ports.map { | port | Server.new(port: port) }

      Async do | task |
        @servers.each { |server| task.async { server.start } }

        Signal.trap("INT") do
          @shutdown = true
          task.stop
        end
      end

      #@ports.each do | port |
      #  server = Server.new(port: port)
      #  @servers.push server
      #  Thread.new { server.start }
      #end

      @logger.info("SMTP Servers started.")

      until @shutdown
        sleep 1
      end

      @logger.info("Interrupt received, shutting down servers...")

      stop

      @logger.info("Daemon has stopped.")
    end

    def stop
      @servers.each(&:stop)
    end

  end

  class Server

    def initialize(port: 2525)
      @port      = port
      @logger    = Logger.new(STDOUT)
      @semaphore = Async::Semaphore.new(4) # Limit to 4 concurrent connections
      @sessions  = [ ]
    end

    def start
      @logger.info("SMTP Server starting on port: #{ @port }")

      @endpoint = Async::IO::Endpoint.tcp('127.0.0.1', @port)

      @logger.info("Listening on port #{ @port }")

      @task = Async do | task |
        @semaphore.async do
          @endpoint.accept do | client |
            handle_client(client)
          end
        end

      end
    end

    def stop
      @logger.info("Stopping server on port: #{ @port }")
      @task.stop if @task
      @sessions.each(&:close)
    end

    private

    def handle_client(client)
      session = Session.new(client)
      @sessions.push session

      @logger.info("Client connected: #{client}")
      client.write "220 Welcome to the SMTP server\r\n"

      loop do
        data = client.readpartial(1024)

        break if data.nil?

        session.update_buffer(data)
        @logger.info("Received data: #{ data.chomp }")

        # Check for QUIT command
        if session.buffer.include?("QUIT\r\n")
          @logger.info("QUIT command received")
          client.write "221 Bye\r\n"
          break
        end

        # Check for end-of-message indicators
        if session.buffer.include?("\r\n.\r\n")
          @logger.info("End of message received")
          client.write "250 OK\r\n"
          session.clear_buffer
        end
      end

      client.close
      @logger.info("Client disconnected")
      @sessions.delete(session)
    end

  end

  class Session
    attr_reader :client, :buffer, :connected_at, :last_data_received_at

    def initialize(client)
      @client = client
      @buffer = ""
      @connected_at = Time.now
      @last_data_received_at = Time.now
    end

    def update_buffer(data)
      @buffer << data
      @last_data_received_at = Time.now
    end

    def clear_buffer
      @buffer.clear
    end

    def close
      @client.close
    end
  end

end
