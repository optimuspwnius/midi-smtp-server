require 'logger'
require 'async'
require 'async/semaphore'
require 'async/io'

module SmtpServer
  class Daemon
    def initialize ports: [2525]
      @shutdown = false
      @servers  = []
      @logger   = Logger.new STDOUT
      @ports    = ports
    end

    def start
      @logger.info "SMTP Servers starting on ports: #{ @ports.join ', ' }"

      @servers = @ports.map { | port | Server.new port: port }

      Async do | task |
        @servers.each do | server |
          task.async do
            server.start
          end
        end

        Signal.trap "INT" do
          @shutdown = true
          task.stop
        end

        @logger.info "SMTP Servers started."
      end

      until @shutdown
        sleep 1
      end

      @logger.info ""
      @logger.info "Interrupt received, shutting down servers..."

      stop

      @logger.info "Daemon has stopped."
    end

    def stop
      @servers.each &:stop
      @servers.clear
      @shutdown = false
    end
  end
end
