require 'curses'

Curses.noecho
Curses.init_screen

def memory
  file = File.new('/proc/meminfo')
  meminfo_regex = /(MemTotal.*)|(Active:.*)|(SwapTotal.*)|(SwapFree.*)/
  output = "Memory Usage\t"
  file.each_line do |line|
    output += "#{meminfo_regex.match(line)[0]}\t" if meminfo_regex.match(line)
  end
  Curses.setpos(1, 0)
  Curses.addstr(output)
  Curses.refresh
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
  output = "Uptime: #{sec_to_days(/([^\s]+)/.match(file.read)[0].to_i)}"
  Curses.setpos(2, 0)
  Curses.addstr(output)
  Curses.refresh
end

def reg_matcher(regex, string)
  regex.match(string)[0].split[1]
end

def load_average
  file = File.new('/proc/loadavg').read.split
  output = "Load Average:\t"
  file.each_with_index do |data, index|
    output += '%5s' % data
    break if index == 2
  end
  Curses.setpos(2, 65)
  Curses.addstr(output)
  Curses.refresh
end

def processes
  printf '%15s%15s%15s%15s%15s', 'Name', 'state', 'Pid', 'Uid', 'Gid'
  process_regex = [/Name.*/, /State:.*/, /Pid:.*/, /Uid:.*/, /Gid:.*/]
  Dir.each_child('/proc') do |dir|
    if /^[0-9]*$/ =~ dir
      content = File.new("/proc/#{dir}/status").read
      process_regex.each do |regex|
        printf '%15s', reg_matcher(regex, content)
      end
    end
  end
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
  output = "CPU Usage%:\t"
  usage.zip(val_array).each do |usg, des|
    output += "#{'%8s' % usg}#{'%3s' % des}"
  end
  Curses.setpos(4, 0)
  Curses.addstr(output)
  Curses.refresh
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
    sleep 2
  end
end

def let_it_burn(threads)
  Curses.setpos(50, 50)
  Curses.addstr('Burning it ALL!')
  Curses.refresh
  threads.each do |t|
    Thread.kill t
  end
  Curses.close_screen
end

def key_press_detection(threads)
  check = Curses.getch
  let_it_burn threads if check == 'q'
end

threads = []
threads << Thread.new do
  loop do
    memory
    sleep 1
  end
end

threads << Thread.new do
  loop do
    uptime
    sleep 1
  end
end
# processes
threads << Thread.new do
  loop do
    load_average
    sleep 1
  end
end
threads << Thread.new { cpu_usage }
threads << Thread.new do
  loop do
    key_press_detection threads
    sleep 1
  end
end
threads.each(&:join)
