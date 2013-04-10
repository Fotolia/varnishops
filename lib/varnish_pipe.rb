class VarnishPipe
  attr_accessor :stats, :semaphore, :start_time

  def initialize(config)
    @stats = {
      :total_reqs => 0,
      :total_bytes => 0,
      :requests => {},
      :calls => {},
      :hitratio => {},
      :reqps => {},
      :bps => {},
    }

    @semaphore = Mutex.new
    @avg_period = config[:avg_period]
  end

  def start
    @stop = false
    @start_time = Time.new.to_f
    @start_ts = @start_time.to_i

    IO.popen("varnishncsa -F '%U %{Varnish:hitmiss}x %b'").each_line do |line|
      if line =~ /^(\S+) (\w+) (\d+)$/
        url, status, bytes = $1, $2, $3
        key = nil

        case url
          when /^\/r\/v2010\/[a-f0-9]{40}\/([a-z]+)\/.*$/
            key = "r:#{$1}"
          when /^\/jpg((\/\d{2}){4})\/(\d{3}).*_PXP\.jpg$/
            key = "jpg:#{$3}:PX"
          when /^\/jpg((\/\d{2}){4})\/(\d{3}).*\.(\w{3})$/
            key = "#{$4}:#{$3}"
          when /^\/v2010\/(\w+)\/.*$/
            key = "v2010:#{$1}"
          when /^\/(\w+)\/.*$/
            key = $1
        end

        if key
          @semaphore.synchronize do
            duration = (Time.now.to_i - @start_ts)
            it = duration / @avg_period
            idx = duration % @avg_period

            @stats[:requests][key] ||= {
              :hit => Array.new(@avg_period, 0),
              :miss => Array.new(@avg_period, 0),
              :bytes => Array.new(@avg_period, 0),
              :it => Array.new(@avg_period, 0),
              :last => ""
            }

            cur_req = @stats[:requests][key]
            if cur_req[:it][idx] < it
              cur_req[status.to_sym][idx] = 0
              cur_req[:bytes][idx] = 0
            end
            cur_req[status.to_sym][idx] += 1
            cur_req[:bytes][idx] += bytes.to_i
            cur_req[:it][idx] = it
            cur_req[:last] = url
            @stats[:total_reqs] += 1
            @stats[:total_bytes] += bytes.to_i
          end
        end
      end

      break if @stop
    end
  end

  def stop
    @stop = true
  end
end
