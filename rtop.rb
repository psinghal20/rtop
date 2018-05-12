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

# To-do: User list utility for mapping uid, gid to user

def processes
  printf '%15s%15s%15s%15s%15s', 'Name', 'state', 'Pid', 'Uid', 'Gid'
  process_regex = [/Name.*/, /State:.*/, /Pid:.*/, /Uid:.*/, /Gid:.*/]
  Dir.each_child('/proc') do |dir|
    if /^[0-9]*$/ =~ dir
      content = File.new("/proc/#{dir}/status").read
      puts
      process_regex.each do |regex|
        printf '%15s', reg_matcher(regex, content)
      end
    end
  end
end

def cpu_usage_to_percentages(usage)
  cpu_tot = usage.map!(&:to_f).reduce(0, :+)
  usage.map! do |usg|
    ((usg / cpu_tot) * 100).round 2
  end
end

# def cpu_refresh
# end

def cpu_usage
  val_array = %w[us ni sy id wa hi si st]
  file = File.new('/proc/stat')
  usage = file.first.split[1, 8]
  usage = cpu_usage_to_percentages usage
  temp = "CPU Usage%: \t"
  usage.zip(val_array).each do |usg, des|
    temp += "#{'%8s' % usg}#{'%3s' % des}"
  end
  Curses.setpos(4, 0)
  Curses.addstr(temp)
  Curses.refresh
  sleep(5)
end

mem = Thread.new do
  loop do
    memory
    sleep 1
  end
end

up = Thread.new do
  loop do
    uptime
    sleep 1
  end
end
# processes
load_avg = Thread.new do
  loop do
    load_average
    sleep 1
  end
end
cpu_usage
mem.join
up.join
load_avg.join
Curses.close_screen
