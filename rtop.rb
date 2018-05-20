#!/usr/bin/env ruby
require 'curses'

# Rtop class
class Rtop
  def curses_init
    Curses.noecho
    Curses.curs_set 0
    Curses.init_screen
    @status_window = Curses::Window.new(20, Curses.cols, 0, 0)
    @process_window = Curses::Window.new(100, Curses.cols, 7, 0)
    Curses.stdscr.keypad true
    Curses.stdscr.nodelay = true
    @process_window.scrollok true
  end

  def bold_text(x_cord, y_cord, string, window)
    window.setpos(x_cord, y_cord)
    window.attron(Curses::A_BOLD) do
      window.addstr(string)
    end
    window.refresh
  end

  def print_text(x_cord, y_cord, string, window)
    window.setpos(x_cord, y_cord)
    window.addstr(string)
    window.refresh
  end

  def memory
    file = File.new('/proc/meminfo')
    meminfo_regex = /(MemTotal.*)|(Active:.*)|(SwapTotal.*)|(SwapFree.*)/
    bold_text 1, 0, "Memory Usage\t", @status_window
    output = ''
    file.each_line do |line|
      output += "#{meminfo_regex.match(line)[0]}\t" if meminfo_regex.match(line)
    end
    print_text 1, 15, output, @status_window
  end

  def sec_to_days(time)
    day = time / (24 * 3600)
    time = time % (24 * 3600)
    hour = time / 3600
    time %= 3600
    min = time / 60
    seconds = time % 60
    "up #{day} day, #{hour} hour, #{min} minutes, #{seconds} seconds"
  end

  def uptime
    file = File.new('/proc/uptime')
    bold_text 2, 0, 'Uptime:', @status_window
    output = sec_to_days(/([^\s]+)/.match(file.read)[0].to_i).to_s
    print_text 2, 10, output, @status_window
  end

  def reg_matcher(regex, string)
    regex.match(string)[0].split[1]
  end

  def load_average
    file = File.new('/proc/loadavg').read.split
    bold_text 2, 65, "Load Average:\t", @status_window
    output = ''
    file.each_with_index do |data, index|
      output += '%5s' % data
      break if index == 2
    end
    print_text 2, 80, output, @status_window
  end

  def parse_process_status(dir)
    begin
      content = File.new("/proc/#{dir}/status").read
    rescue; end
    regex_list = { name: /Name.*/, state: /State:.*/, pid: /Pid:.*/,
                   uid: /Uid:.*/, gid: /Gid:.*/, threads: /Threads:.*/ }
    process = {}
    regex_list.each do |key, value|
      process[key] = value.match(content)[0].split[1]
    end
    process
  end

  def gen_process_list
    @processes = []
    Dir.each_child('/proc') do |dir|
      @processes << parse_process_status(dir) if /^[0-9]*$/ =~ dir
    end
    tasks_stats
    process_list
  end

  def user_list
    @users = []
    file = File.new('/etc/passwd')
    file.each_line do |line|
      usr = line.split(':')
      @users << { name: usr[0], uid: usr[2], gid: usr[3] }
    end
  end

  def process_list
    process_header = '%8s%20s%8s%8s%8s' % %w[PID Name UID GID State]
    bold_text 0, 0, process_header, @process_window
    index = 1
    @processes[@process_index..@process_window.maxy].each do |proc|
      output = '%8s%20s%8s%8s%8s' % [proc[:pid], proc[:name], proc[:uid], proc[:gid], proc[:state]]
      @process_window.setpos(index, 0)
      @process_window.addstr(output)
      index += 1
    end
    @process_window.refresh
  end

  def tasks_stats
    tot_count = @processes.length
    running_count = @processes.count { |proc| proc[:state] == 'R' }
    sleeping_count = @processes.count { |proc| proc[:state] == 'S' }
    stopped_count = @processes.count { |proc| proc[:state] == 'T' }
    zombie_count = @processes.count { |proc| proc[:state] == 'Z' }
    bold_text 5, 0, 'Tasks:', @status_window
    output = " #{tot_count} total,  #{running_count} running, #{sleeping_count} sleeping, #{stopped_count} stopped, #{zombie_count} zombie"
    print_text 5, 10, output, @status_window
  end

  def cpu_usage_to_percentages(old_usage, new_usage)
    val_array = %w[us ni sy id wa hi si st]
    usage = new_usage.zip(old_usage).map do |new_usg, old_usg|
      new_usg.to_i - old_usg.to_i
    end
    cpu_tot = usage.map!(&:to_f).reduce(0, :+)
    usage.map! do |usg|
      ((usg / cpu_tot) * 100).round 2
    end
    bold_text 4, 0, "CPU Usage%:\t", @status_window
    output = ''
    usage.zip(val_array).each do |usg, des|
      output += "#{'%8s' % usg}#{'%3s' % des}"
    end
    print_text 4, 10, output, @status_window
  end

  def cpu_stat_read
    file = File.new('/proc/stat')
    file.first.split[1, 8]
  end

  def cpu_usage
    old_usage = [0, 0, 0, 0, 0, 0, 0, 0]
    loop do
      new_usage = cpu_stat_read
      cpu_usage_to_percentages old_usage, new_usage
      old_usage = new_usage
      sleep 1
    end
  end

  def thread_init
    @threads = []
    @threads << Thread.new do
      loop do
        memory
        sleep 1
      end
    end

    @threads << Thread.new do
      loop do
        uptime
        sleep 1
      end
    end

    @threads << Thread.new do
      loop do
        load_average
        sleep 1
      end
    end

    @threads << Thread.new { cpu_usage }

    @threads << Thread.new do
      loop do
        gen_process_list
        sleep 0.1
      end
    end

    @threads << Thread.new do
      loop do
        key_press_detection
      end
    end
    @threads.each(&:join)
  end

  def let_it_burn
    @threads.each do |t|
      Thread.kill t
    end
    Curses.close_screen
  end

  def key_press_detection
    check = Curses.getch
    let_it_burn if check == 'q'
    @process_index += 1 if check == Curses::Key::DOWN && @process_index < @processes.length
    @process_index -= 1 if check == Curses::Key::UP && @process_index > 0
  end

  def initialize
    @process_index = 0
    @users = []
    @processes = []
    curses_init
    thread_init
  end
end
Rtop.new
