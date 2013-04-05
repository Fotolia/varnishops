require 'curses'

include Curses

class UI
  def initialize(config)
    @config = config

    init_screen
    cbreak
    curs_set(0)

    # set keyboard input timeout - sneaky way to manage refresh rate
    Curses.timeout = @config[:refresh_rate]

    if can_change_color?
      start_color
      init_pair(0, COLOR_WHITE, COLOR_BLACK)
      init_pair(1, COLOR_WHITE, COLOR_BLUE)
      init_pair(2, COLOR_WHITE, COLOR_RED)
    end

    @stat_cols    = %w[ calls req/sec hitratio ]
    @stat_col_width = 10
    @key_col_width  = 0

    @commands = {
      'Q' => "quit",
      'C' => "sort by calls",
      'R' => "sort by req/sec",
      'H' => "sort by hitratio",
      'T' => "toggle sort order (asc|desc)"
    }
  end

  def header
    # pad stat columns to @stat_col_width
    @stat_cols = @stat_cols.map { |c| sprintf("%#{@stat_col_width}s", c) }

    # key column width is whatever is left over
    @key_col_width = cols - (@stat_cols.length * @stat_col_width)

    attrset(color_pair(1))
    setpos(0,0)
    addstr(sprintf "%-#{@key_col_width}s%s", "request type", @stat_cols.join)
  end

  def footer
    footer_text = @commands.map { |k,v| "#{k}:#{v}" }.join(' | ')
    setpos(lines-1, 0)
    attrset(color_pair(2))
    addstr(sprintf "%-#{cols}s", footer_text)
  end

  def render_stats(pipe, sort_mode, sort_order = :desc)
    render_start_t = Time.now.to_f * 1000

    # subtract header + footer lines
    maxlines = lines - 3
    offset = 1

    # construct and render footer stats line
    setpos(lines-2,0)
    attrset(color_pair(2))
    header_summary = sprintf "%-28s %-14s",
      "sort mode: #{sort_mode.to_s} (#{sort_order.to_s})",
      "requests: #{pipe.stats[:req_nb]}"
    addstr(sprintf "%-#{cols}s", header_summary)

    # reset colours for main key display
    attrset(color_pair(0))

    top = []

    pipe.semaphore.synchronize do
      # we may have seen no packets received on the pipe thread
      return if pipe.stats[:start_time].nil?

      elapsed = Time.now.to_f - pipe.stats[:start_time]

      # calculate hits+misses, req/sec and hitratio
      pipe.stats[:requests].each do |key,values|
        total = values[:hit] + values[:miss]

        pipe.stats[:calls][key] = total
        pipe.stats[:reqps][key] = total.to_f / elapsed
        pipe.stats[:hitratio][key] = values[:hit].to_f * 100 / total

      end

      top = pipe.stats[sort_mode].sort { |a,b| a[1] <=> b[1] }
    end

    unless sort_order == :asc
      top.reverse!
    end

    for i in 0..maxlines-1
      if i < top.length
        k = top[i][0]
        v = top[i][1]

        # if the key is too wide for the column truncate it and add an ellipsis
        if k.length > @key_col_width
          display_key = k[0..@key_col_width-4]
          display_key = "#{display_key}..."
        else
          display_key = k
        end

        # render each key
        line = sprintf "%-#{@key_col_width}s %9.d %9.2f %9.2f",
                 display_key,
                 pipe.stats[:calls][k],
                 pipe.stats[:reqps][k],
                 pipe.stats[:hitratio][k]
      else
        # clear remaining lines
        line = " "*cols
      end

      setpos(1+i, 0)
      addstr(line)
    end

    # print render time in status bar
    runtime = (Time.now.to_f * 1000) - render_start_t
    attrset(color_pair(2))
    setpos(lines-2, cols-24)
    addstr(sprintf "render time: %4.3f (ms)", runtime)
  end

  def input_handler
    # Curses.getch has a bug in 1.8.x causing non-blocking
    # calls to block reimplemented using IO.select
    if RUBY_VERSION =~ /^1.8/
      refresh_secs = @config[:refresh_rate].to_f / 1000

      if IO.select([STDIN], nil, nil, refresh_secs)
        c = getch
        c.chr
      else
        nil
      end
    else
      getch
    end
  end

  def stop
    nocbreak
    close_screen
  end
end
