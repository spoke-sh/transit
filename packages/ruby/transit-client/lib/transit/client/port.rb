# frozen_string_literal: true
require 'tmpdir'

module Transit
  module Internal
    class Port
      def initialize(executable, configuration, schemas, request_name)
        unless File.file?(executable) && File.executable?(executable)
          raise IncompatibleNative, 'Install the matching native 0.2.0 gem or supply native_host'
        end
        document = JSON.generate(configuration)
        raise ArgumentError, 'Native configuration exceeds its bound' if document.bytesize > LIMITS.fetch('host_config_bytes')
        @schemas, @request_name, @closed = schemas, request_name, false
        @directory = Dir.mktmpdir('transit-ruby-')
        @file = File.join(@directory, 'host.json')
        File.open(@file, 'wb', 0o600) { |file| file.write(document) }
        input, @input = IO.pipe
        @output, output = IO.pipe
        begin
          @pid = Process.spawn(executable, @file, in: input, out: output, err: File::NULL, close_others: true)
        rescue SystemCallError
          close
          raise IncompatibleNative, 'Unable to start the version-matched native host'
        ensure
          input.close
          output.close
        end
      end
      def schema(name) = @schemas.fetch(name)
      def request(value, phase:, mutation: false, response: nil)
        raise Closed, 'Native port is closed' if @closed
        Internal.validate!(schema(@request_name), value)
        line = JSON.generate(value).b << "\n"
        bound = LIMITS.fetch('host_line_bytes')
        raise ArgumentError, 'Native request exceeds its bound' if line.bytesize > bound
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 65
        begin
          raise IOError if IO.select([@output], nil, nil, 0)
          offset = 0
          while offset < line.bytesize
            sent = @input.write_nonblock(line.byteslice(offset..), exception: false)
            if sent == :wait_writable
              await_io(nil, [@input], deadline)
            else
              offset += sent
            end
          end
          incoming = ''.b
          loop do
            chunk = @output.read_nonblock([16_384, bound - incoming.bytesize + 1].min, exception: false)
            if chunk == :wait_readable
              await_io([@output], nil, deadline)
              next
            end
            raise IOError if chunk.nil?
            incoming << chunk
            raise IOError if incoming.bytesize > bound
            break if incoming.include?("\n")
          end
          raise IOError unless incoming.index("\n") == incoming.bytesize - 1
          incoming.force_encoding(Encoding::UTF_8)
          raise IOError unless incoming.valid_encoding?
          result = JSON.parse(incoming)
          unless result.is_a?(Hash) && result.keys.sort == %w[status value] && result['status'].is_a?(Integer) && result['status'].between?(0, 14)
            raise IOError
          end
          if result['status'].zero? && response && !Internal.valid?(schema(response), result['value'])
            raise IOError
          end
        rescue IOError, SystemCallError, JSON::ParserError
          @closed = true
          signal('TERM')
          category = mutation ? UnknownOutcome : ReadFailed
          raise category.new('Native exchange failed; retain mutation recovery material', status: mutation ? 6 : 7, phase: phase)
        end
        raise Internal.native_error(result['status'], result['value'], phase) unless result['status'].zero?
        result['value']
      end
      def close
        @closed = true
        @input&.close unless @input&.closed?
        if @pid
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
          loop do
            break if Process.waitpid(@pid, Process::WNOHANG)
            if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
              signal('KILL')
              Process.waitpid(@pid)
              break
            end
            sleep 0.01
          end
          @pid = nil
        end
      ensure
        @output&.close unless @output&.closed?
        File.unlink(@file) if @file && File.exist?(@file)
        Dir.rmdir(@directory) if @directory && Dir.exist?(@directory)
      end
      private
      def signal(name)
        Process.kill(name, @pid)
      rescue Errno::ESRCH
        nil
      end
      def await_io(readers, writers, deadline)
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise IOError if remaining <= 0 || !IO.select(readers, writers, nil, remaining)
      end
    end
  end
end
