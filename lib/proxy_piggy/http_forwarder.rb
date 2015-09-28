module ProxyPiggy
  class HTTPForwarder

    def initialize(reactor, request_connection, request)
      @reactor = reactor
      @host = request.match(/^Host: (.+)\r$/)[1]
      @request = request
      @request_connection = request_connection
    end

    def connect
      @reactor.connect(@host, 80).then do |connection|
        @connection = connection
        @connection.on_data(&method(:forward_response))
        self
      end
    end

    def send_request
      @connection.write(@request)
    end

    private

    def forward_response(data)
      @request_connection.write(data)
    end

  end
end
