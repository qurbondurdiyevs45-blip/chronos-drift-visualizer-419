require 'optparse'
require 'socket'
require 'json'
require 'timeout'

class ChronosStressTester
  def initialize(options)
    @target_host = options[:host] || '127.0.0.1'
    @target_port = options[:port] || 5000
    @duration = options[:duration] || 60
    @frequency = options[:frequency] || 0.01 # 10ms intervals
    @results = []
    @running = false
  end

  def run
    puts "--- Chronos Drift Visualizer: Stress Test Orchestrator ---"
    puts "Target: #{@target_host}:#{@target_port}"
    puts "Frequency: #{@frequency}s | Duration: #{@duration}s"
    
    @running = true
    start_time = Time.now.to_f
    end_time = start_time + @duration

    trap("INT") do
      @running = false
      puts "\nInterrupt received. Finalizing reports..."
    end

    begin
      while @running && Time.now.to_f < end_time
        sample_drift
        sleep @frequency
      end
    rescue StandardError => e
      puts "Fatal error during benchmark: #{e.message}"
    ensure
      generate_report
    end
  end

  private

  def sample_drift
    # Capture local monotonic and wall clock
    local_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    wall_time = Time.now.to_f

    begin
      # Attempt to sync with the Chronos Node (Node.js/Rust backend)
      Timeout.timeout(0.05) do
        socket = TCPSocket.new(@target_host, @target_port)
        payload = {
          client_ts: wall_time,
          type: 'STRESS_PROBE'
        }.to_json
        
        socket.puts(payload)
        response = socket.gets
        socket.close

        if response
          remote_data = JSON.parse(response)
          local_end = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          rtt = local_end - local_start
          
          # Calculate drift: (Client Send + Client Recv) / 2 vs Server Time
          server_ts = remote_data['server_ts'].to_f
          estimated_drift = (server_ts - (wall_time + (rtt / 2.0))) * 1000.0
          
          @results << {
            offset: estimated_drift,
            rtt: rtt * 1000.0,
            timestamp: wall_time
          }
        end
      end
    rescue Errno::ECONNREFUSED
      # Node might be under heavy load or down
      @results << { error: 'REFUSED', timestamp: wall_time }
    rescue Timeout::Error
      @results << { error: 'TIMEOUT', timestamp: wall_time }
    rescue StandardError => e
      @results << { error: e.class.to_s, timestamp: wall_time }
    end
  end

  def generate_report
    valid_samples = @results.reject { |r| r[:error] }
    errors = @results.select { |r| r[:error] }

    puts "\n--- Benchmark Completed ---"
    puts "Total Samples Attempted: #{@results.size}"
    puts "Successful Samples:     #{valid_samples.size}"
    puts "Failed Samples:         #{errors.size}"

    if valid_samples.any?
      offsets = valid_samples.map { |s| s[:offset] }
      rtts = valid_samples.map { |s| s[:rtt] }

      avg_drift = offsets.sum / offsets.size.to_f
      max_drift = offsets.map(&:abs).max
      p99_rtt = rtts.sort[(rtts.size * 0.99).to_i]

      puts "Average Drift:          #{avg_drift.round(4)} ms"
      puts "Peak Absolute Drift:    #{max_drift.round(4)} ms"
      puts "P99 RTT:                #{p99_rtt.round(4)} ms"
      
      filename = "drift_bench_#{Time.now.to_i}.json"
      File.write(filename, JSON.pretty_generate(@results))
      puts "Full trace exported to #{filename}"
    else
      puts "Insufficient data to calculate drift metrics."
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby benchmark.rb [options]"

  opts.on("-u", "--host HOST", "Target host address") { |v| options[:host] = v }
  opts.on("-p", "--port PORT", Integer, "Target port") { |v| options[:port] = v }
  opts.on("-d", "--duration SEC", Integer, "Duration of test in seconds") { |v| options[:duration] = v }
  opts.on("-f", "--frequency SEC", Float, "Time between probes (default 0.01)") { |v| options[:frequency] = v }
end.parse!

tester = ChronosStressTester.new(options)
tester.run