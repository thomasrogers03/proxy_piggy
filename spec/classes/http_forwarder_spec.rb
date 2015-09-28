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

  end
end
