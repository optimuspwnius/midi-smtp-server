#$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'smtp-server/version'

Gem::Specification.new do |s|
  s.name        = 'smtp-server'
  s.version     = SmtpServer::VERSION::STRING
  s.date        = SmtpServer::VERSION::DATE
  s.description = 'Ruby SMTP Server.'
  s.files       = [
    'README.md',
    'CHANGELOG.md',
    'MIT-LICENSE.txt',
    'lib/smtp-server.rb',
    'lib/smtp-server/version.rb',
    'lib/smtp-server/exceptions.rb',
    'lib/smtp-server/logger.rb',
    'lib/smtp-server/tls-transport.rb'
  ]
  s.required_ruby_version = '>= 3.0.0'
end
