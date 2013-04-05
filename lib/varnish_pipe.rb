class VarnishPipe
  attr_accessor :stats, :semaphore

  def initialize
    @stats = {
      :req_nb => 0,
      :requests => {},
      :calls => {},
      :hitratio => {},
      :reqps => {},
    }

    @semaphore = Mutex.new
  end

  def start
    @stop = false
    @stats[:start_time] = Time.new.to_f

    IO.popen("varnishncsa -F '%U %{Varnish:hitmiss}x'").each_line do |line|
      if line =~ /^(\S+) (\S+)$/
        url, status = $1, $2
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

        @semaphore.synchronize do
          if key
            @stats[:requests][key] ||= { :hit => 0, :miss => 0 }
            @stats[:requests][key][status.to_sym] += 1
            @stats[:req_nb] += 1
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
