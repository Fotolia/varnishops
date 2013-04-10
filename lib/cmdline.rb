require 'optparse'

class CmdLine
  def self.parse(args)
    @config = {}

    opts = OptionParser.new do |opt|
      @config[:discard_thresh] = 0
      opt.on '-d', '--discard=THRESH', Float, 'Discard keys with request/sec rate below THRESH' do |discard_thresh|
        @config[:discard_thresh] = discard_thresh
      end

      @config[:refresh_rate] = 500
      opt.on '-r', '--refresh=MS', Float, 'Refresh the stats display every MS milliseconds' do |refresh_rate|
        @config[:refresh_rate] = refresh_rate
      end

      @config[:avg_period] = 60
      opt.on '-a', '--avg-period=SEC', Integer, 'Compute averages over SEC seconds' do |avg_period|
        @config[:avg_period] = avg_period
      end

      opt.on_tail '-h', '--help', 'Show usage info' do
        puts opts
        exit
      end
    end

    opts.parse!

    # limit data structures size
    @config[:avg_period] = 600 if @config[:avg_period] > 600
    @config[:avg_period] = 10 if @config[:avg_period] < 10

    @config
  end
end
