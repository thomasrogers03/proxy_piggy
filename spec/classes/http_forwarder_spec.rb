require 'rspec'

module ProxyPiggy
  describe HTTPForwarder do

    let(:uri_string) { 'http://www.example.com' }
    let(:uri) { URI.parse(uri_string) }
    let!(:request_connection) { global_reactor.connect('localhost', 9998).get }
    let!(:response_connection) { global_reactor.connect('somehost', 9999).get }
    let(:response_connection_future) do
      promise = Ione::Promise.new
      promise.fulfill(response_connection)
      promise.future
    end
    let(:request) do
      %Q{GET #{uri.to_s} HTTP/1.1\r
Connection: close\r
Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r
Accept: */*\r
User-Agent: Ruby\r
Host: #{uri.host}\r
      \r
      }
    end

    subject { HTTPForwarder.new(global_reactor, request_connection, request) }

    before do
      allow(global_reactor).to receive(:connect).with(uri.host, 80).and_return(response_connection_future)
    end

    describe '#connect' do
      it 'should connect to the host specified in the HTTP headers with port 80' do
        expect(global_reactor).to receive(:connect).with('www.example.com', 80).and_return(response_connection_future)
        subject.connect
      end

      context 'with a proxy specified' do
        let(:proxy_options) { {host: '1.2.3.4', port: 5} }

        subject { HTTPForwarder.new(global_reactor, request_connection, request, proxy_options) }

        it 'should forward the request to the proxy' do
          expect(global_reactor).to receive(:connect).with('1.2.3.4', 5).and_return(response_connection_future)
          subject.connect
        end
      end

      it 'should return an Ione::Future' do
        expect(subject.connect).to be_a_kind_of(Ione::Future)
      end

      it 'should return a future resolving to itself' do
        expect(subject.connect.get).to eq(subject)
      end

      context 'with a different host' do
        let(:uri_string) { 'http://www.google.com' }

        it 'should connect to the host specified in the HTTP headers with port 80' do
          expect(global_reactor).to receive(:connect).with('www.google.com', 80).and_return(response_connection_future)
          subject.connect
        end
      end
    end

    describe '#send_request' do
      let(:responses) { %w(response1) }

      before do
        subject.connect.get
        allow(response_connection).to receive(:write).and_call_original
        allow(response_connection).to receive(:write).with(request) do
          response_connection.flush
          responses.each do |response|
            response_connection.write(response)
            response_connection.flush
          end
        end
      end

      it 'should forward responses to the request connection' do
        subject.send_request
        expect(request_connection.buffer.to_str).to eq('response1')
      end

      context 'with a different request' do
        let(:uri_string) { 'http://www.google.com' }
        let(:responses) { %w(http_header\r\n http_body) }

        it 'should forward all responses to the original connection' do
          subject.send_request
          expect(request_connection.buffer.to_str).to eq('http_header\r\nhttp_body')
        end
      end
    end

    describe '#new_request' do
      before { subject.connect }

      it 'should update the request with the new data' do
        subject.new_request("GET stuff HTTP/1.1...\r\n\r\n")
        expect(response_connection).to receive(:write).with("GET stuff HTTP/1.1...\r\n\r\n")
        subject.send_request
      end

      context 'with a different request' do
        it 'should update the request with the new data' do
          subject.new_request("POST stuff HTTP/2.0...\r\n\r\n")
          expect(response_connection).to receive(:write).with("POST stuff HTTP/2.0...\r\n\r\n")
          subject.send_request
        end
      end
    end

    describe '#close' do
      before { subject.connect.get }

      it 'should close the underlying response connection' do
        closed = false
        response_connection.on_closed { closed = true }
        subject.close
        expect(closed).to eq(true)
      end
    end

    describe '#on_closed' do
      it 'should run the callback whenever the response connection is closed' do
        closed = false
        subject.connect.get
        subject.on_closed { closed = true }
        response_connection.close
        expect(closed).to eq(true)
      end

      context 'when the callback is specified before connecting' do
        it 'should forward the callback when connecting' do
          closed = false
          subject.on_closed { closed = true }
          subject.connect.get
          response_connection.close
          expect(closed).to eq(true)
        end
      end
    end

  end
end
