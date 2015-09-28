module ProxyPiggy
  class HTTPForwarder

    def initialize(reactor, request_connection, request, proxy_options = {})
      @reactor = reactor
      @host = proxy_options[:host] || request.match(/^Host: (.+)\r$/)[1]
      @port = proxy_options[:port] || 80
      @request = request
      @request_connection = request_connection
    end

    def connect
      @reactor.connect(@host, @port).then do |connection|
        @connection = connection
        @connection.on_closed(&@on_closed_callback)
        @connection.on_data(&method(:forward_response))
        self
      end
    end

    def new_request(request)
      @request = request
    end

    def send_request
      @connection.write(@request)
    end

    def close
      @connection.close
    end

    def on_closed(&callback)
      @on_closed_callback = callback
      @connection.on_closed(&callback) if @connection
    end

    private

    def forward_response(data)
      @request_connection.write(data)
    end

  end
end
