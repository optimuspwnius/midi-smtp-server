# Assuming the Client class is the same as the Session class in the original code
module SmtpServer
  class Session
    attr_reader :buffer

    def initialize client
      @client = client
      @buffer = ""
    end

    def update_buffer data
      @buffer << data
    end

    def clear_buffer
      @buffer.clear
    end

    def close
      @client.close
    end
  end
end
