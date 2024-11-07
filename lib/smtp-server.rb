require 'logger'
require 'socket'
require 'resolv'
require 'base64'
require 'async'
require 'async/semaphore'
require 'async/io'
require 'net/smtp'
require_relative 'smtp-server/server'
require_relative 'smtp-server/session'

module SmtpServer
  class << self
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
