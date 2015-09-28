require 'rspec'

module ProxyPiggy
  describe Bridge do

    let(:uri_string) { 'http://www.example.com' }
    let(:uri) { URI.parse(uri_string) }
    let(:request_connection) { global_reactor.connect('localhost', 9998).get }
    let(:forwarder) { double(:forwarder, connect: nil, send_request: nil, new_request: nil) }
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

    subject { Bridge.new(global_reactor, request_connection) }

    before do
      allow(forwarder).to receive(:connect).and_return(connected_future)
      allow(HTTPForwarder).to receive(:new).with(global_reactor, request_connection, original_request).and_return(forwarder)
    end

    describe 'bridging connections between the client and server' do
      it 'should create a forwarder and connect to the server' do
        subject
        expect(forwarder).to receive(:connect)
        request_connection.write(original_request)
        request_connection.flush
      end

      it 'should send the initial request' do
        subject
        expect(forwarder).to receive(:send_request)
        request_connection.write(original_request)
        request_connection.flush
      end

      context 'with a different initial request' do
        let(:uri_string) { 'http://www.google.com' }

        it 'should create a forwarder and connect to the server' do
          subject
          expect(forwarder).to receive(:connect)
          request_connection.write(original_request)
          request_connection.flush
        end
      end

      context 'with multiple requests' do
        it 'should re-use the same connection for each request' do
          subject
          expect(forwarder).to receive(:new_request).with("GET ... HTTP/2.3\r\n\r\n")
          expect(forwarder).to receive(:send_request).twice
          request_connection.write(original_request)
          request_connection.flush
          request_connection.write("GET ... HTTP/2.3\r\n\r\n")
          request_connection.flush
        end
      end

    end
  end
end
