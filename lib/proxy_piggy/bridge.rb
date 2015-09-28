module ProxyPiggy
  class Bridge

    def initialize(request_connection, proxy_options = {})
      @proxy_options = proxy_options
      Ione::Io::IoReactor.new.start.on_value do |reactor|
        @reactor = reactor
        @request_connection = request_connection
        request_connection.on_data(&method(:handle_request))
      end
    end

    private

    def handle_request(data)
      if @forwarder
        @forwarder.new_request(data)
      else
        @forwarder = HTTPForwarder.new(@reactor, @request_connection, data, @proxy_options).connect.get
        @forwarder.on_closed { @request_connection.close }
        @request_connection.on_closed do
          @forwarder.close
          @reactor.stop
        end
      end
      @forwarder.send_request
    end

  end
end
