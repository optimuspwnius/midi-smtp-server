# frozen_string_literal: true

require 'resolv'

# A small and highly customizable ruby SMTP-Server.
module SmtpServer

  # Encryption modes
  ENCRYPT_MODES = [:TLS_FORBIDDEN, :TLS_OPTIONAL, :TLS_REQUIRED].freeze
  DEFAULT_ENCRYPT_MODE = :TLS_FORBIDDEN

  # Encryption ciphers and methods
  # check https://www.owasp.org/index.php/TLS_Cipher_String_Cheat_Sheet
  TLS_CIPHERS_ADVANCED_PLUS = 'DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256'
  TLS_CIPHERS_ADVANCED      = "#{TLS_CIPHERS_ADVANCED_PLUS}:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256"
  TLS_CIPHERS_BROAD_COMP    = "#{TLS_CIPHERS_ADVANCED}:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA"
  TLS_CIPHERS_WIDEST_COMP   = "#{TLS_CIPHERS_ADVANCED}:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA"
  TLS_CIPHERS_LEGACY        = "#{TLS_CIPHERS_ADVANCED}:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA"
  TLS_METHODS_ADVANCED      = 'TLSv1_2'
  TLS_METHODS_LEGACY        = 'TLSv1_1'

  # class for TlsTransport
  class TlsTransport

    # current TLS OpenSSL::SSL::SSLContext
    attr_reader :ssl_context

    def initialize(cert_path, key_path, ciphers, methods, cert_cn, cert_san, logger)
      # if need to debug something while working with openssl
      # OpenSSL::debug = true

      # save references
      @logger = logger
      @cert_path = cert_path.to_s == '' ? nil : cert_path.strip
      @key_path = key_path.to_s == '' ? nil : key_path.strip
      # create SSL context
      @ssl_context = OpenSSL::SSL::SSLContext.new
      @ssl_context.ciphers = ciphers.to_s == '' ? TLS_CIPHERS_ADVANCED_PLUS : ciphers
      @ssl_context.ssl_version = methods.to_s == '' ? TLS_METHODS_ADVANCED : methods
      # check cert_path and key_path

      # test the paths
      raise "A certificate is required. Please ensure the cert_path is provided." if @cert_path.nil?
      raise "File \"#{@cert_path}\" does not exist or is not a regular file. Could not load certificate." unless File.file?(@cert_path.to_s)
      raise "File \"#{@key_path}\" does not exist or is not a regular file. Could not load private key." unless @key_path.nil? || File.file?(@key_path.to_s)
      # try to load certificate and key
      cert_lines = File.read(@cert_path.to_s).lines
      # check if the cert file contains a chain of certs
      cert_indexes = cert_lines.each_with_index.map { |line, index| index if line.downcase.include?('-begin certificate-') }.compact
      # create each cert in the chain
      certs = []
      cert_indexes.each_with_index do |cert_index, current_index|
        end_index = current_index + 1 < cert_indexes.length ? cert_indexes[current_index + 1] : -1
        certs << OpenSSL::X509::Certificate.new(cert_lines[cert_index..end_index].join)
      end
      # add the cert and optional found chain to context
      @ssl_context.cert = certs.first
      @ssl_context.extra_chain_cert = certs[1..]
      # check if key was given by separate file or should be included in cert
      if @key_path.nil?
        key_index = cert_lines.index { |line| line =~ /-begin[^-]+key-/i }
        end_index = cert_lines.index { |line| line =~ /-end[^-]+key-/i }
        @ssl_context.key = OpenSSL::PKey::RSA.new(cert_lines[key_index..end_index].join)
      else
        @ssl_context.key = OpenSSL::PKey::RSA.new(File.open(@key_path.to_s))
      end
    end

    # start ssl connection over existing tcpserver socket
    def start(io)
      # start SSL negotiation
      ssl = OpenSSL::SSL::SSLSocket.new(io, @ssl_context)
      # connect to server socket
      ssl.accept
      # make sure to close also the underlying io
      ssl.sync_close = true
      # return as new io socket
      return ssl
    end

  end

end
