module ProxyPiggy
  class Bridge

    def initialize(reactor, request_connection)
      @reactor = reactor
      @request_connection = request_connection
      request_connection.on_data(&method(:handle_request))
    end

    private

    def handle_request(data)
      if @forwarder
        @forwarder.new_request(data)
      else
        @forwarder = HTTPForwarder.new(@reactor, @request_connection, data).connect.get
        @forwarder.on_closed { @request_connection.close }
        @request_connection.on_closed { @forwarder.close }
      end
      @forwarder.send_request
    end

  end
end
