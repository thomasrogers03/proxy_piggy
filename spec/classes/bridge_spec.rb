require 'rspec'

module ProxyPiggy
  describe Bridge do

    let(:uri_string) { 'http://www.example.com' }
    let(:uri) { URI.parse(uri_string) }
    let(:request_connection) { global_reactor.connect('localhost', 9998).get }
    let(:proxy_options) { {} }
    let(:forwarder) { double(:forwarder, connect: nil, send_request: nil, new_request: nil, on_closed: nil, close: nil) }
    let(:connected_future) do
      promise = Ione::Promise.new
      promise.fulfill(forwarder)
      promise.future
    end
    let(:original_request) do
      %Q{GET #{uri.to_s} HTTP/1.1\r
Connection: close\r
Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r
Accept: */*\r
User-Agent: Ruby\r
Host: #{uri.host}\r
      \r
      }
    end

    subject { Bridge.new(request_connection) }

    before do
      allow(forwarder).to receive(:connect).and_return(connected_future)
      allow(HTTPForwarder).to receive(:new).with(global_reactor, request_connection, original_request, proxy_options).and_return(forwarder)
      allow(Ione::Io::IoReactor).to receive(:new).and_return(global_reactor)
    end

    describe 'bridging connections between the client and server' do
      it 'should start the reactor' do
        expect(global_reactor).to receive(:start)
        subject
      end

      it 'should create a forwarder and connect to the server' do
        subject
        expect(forwarder).to receive(:connect)
        request_connection.write(original_request)
        request_connection.flush
      end

      context 'with proxy options specified' do
        let(:proxy_options) { {host: '1.2.3.4', port: 5} }

        subject { Bridge.new(request_connection, proxy_options) }

        it 'should create a forwarder and connect to the server' do
          subject
          expect(forwarder).to receive(:connect)
          request_connection.write(original_request)
          request_connection.flush
        end
      end

      it 'should send the initial request' do
        subject
        expect(forwarder).to receive(:send_request)
        send_initial_request
      end

      context 'with a different initial request' do
        let(:uri_string) { 'http://www.google.com' }

        it 'should create a forwarder and connect to the server' do
          subject
          expect(forwarder).to receive(:connect)
          send_initial_request
        end
      end

      context 'with multiple requests' do
        it 'should re-use the same connection for each request' do
          subject
          expect(forwarder).to receive(:new_request).with("GET ... HTTP/2.3\r\n\r\n")
          expect(forwarder).to receive(:send_request).twice
          send_initial_request
          request_connection.write("GET ... HTTP/2.3\r\n\r\n")
          request_connection.flush
        end
      end

      context 'when the server closes the connection' do
        it 'should close the request connection' do
          closed = false
          request_connection.on_closed { closed = true }
          allow(forwarder).to receive(:on_closed).and_yield
          subject
          send_initial_request
          expect(closed).to eq(true)
        end
      end

      context 'when the client closes the connection' do
        it 'should close the connection on the forwarder' do
          subject
          expect(forwarder).to receive(:close)
          send_initial_request
          request_connection.close
        end

        it 'should stop the reactor' do
          subject
          expect(global_reactor).to receive(:stop)
          send_initial_request
          request_connection.close
        end
      end

    end

    private

    def send_initial_request
      request_connection.write(original_request)
      request_connection.flush
    end

  end
end
