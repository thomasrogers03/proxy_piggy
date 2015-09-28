module IoneHelper
  extend RSpec::Core::SharedContext

  class MockConnection
    attr_reader :buffer, :host, :port

    def initialize(host, port)
      @buffer = Ione::ByteBuffer.new
      @host = host
      @port = port
    end

    def write(data = nil)
      if block_given?
        yield buffer
      else
        buffer << data
      end
    end

    def flush
      data = buffer.read(buffer.size)
      @on_data_callback.call(data) if @on_data_callback
    end

    def on_data(&block)
      @on_data_callback = block
    end
  end

  let(:global_reactor) { double(:reactor) }

  before do
    allow(global_reactor).to receive(:connect) do |host, port|
      promise = Ione::Promise.new
      promise.fulfill(MockConnection.new(host, port))
      promise.future
    end
  end
end
