require 'curses'

Curses.noecho
Curses.init_screen
Curses.curs_set 0
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

def parse_process_status(dir)
  content = File.new("/proc/#{dir}/status").read
  regex_list = { name: /Name.*/, state: /State:.*/, pid: /Pid:.*/,
                 uid: /Uid:.*/, gid: /Gid:.*/, threads: /Threads:.*/ }
  process = {}
  regex_list.each do |key, value|
    process[key] = value.match(content)[0].split[1]
  end
  process
end

def gen_process_list
  processes = []
  Dir.each_child('/proc') do |dir|
    processes << parse_process_status(dir) if /^[0-9]*$/ =~ dir
  end
  tasks_stats processes
end

def tasks_stats(processes)
  tot_count = processes.length
  running_count = processes.count { |proc| proc[:state] == 'R' }
  sleeping_count = processes.count { |proc| proc[:state] == 'S' }
  stopped_count = processes.count { |proc| proc[:state] == 'T' }
  zombie_count = processes.count { |proc| proc[:state] == 'Z' }
  output = "Tasks: #{tot_count} total,  #{running_count} running, #{sleeping_count} sleeping, #{stopped_count} stopped, #{zombie_count} zombie"
  Curses.setpos(5, 0)
  Curses.addstr(output)
  Curses.refresh
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

threads << Thread.new do
  loop do
    load_average
    sleep 1
  end
end

threads << Thread.new { cpu_usage }

threads << Thread.new do
  loop do
    gen_process_list
    sleep 1
  end
end

threads << Thread.new do
  loop do
    key_press_detection threads
    sleep 1
  end
end
threads.each(&:join)
