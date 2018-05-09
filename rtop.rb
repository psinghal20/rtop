def memory
  file = File.new('/proc/meminfo')
  meminfo_regex = /(MemTotal.*)|(Active:.*)|(SwapTotal.*)|(SwapFree.*)/
  puts 'Memory Usage'
  file.each_line do |line|
    puts meminfo_regex.match(line) if meminfo_regex.match(line)
  end
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
  puts "Uptime: #{sec_to_days(/([^\s]+)/.match(file.read)[0].to_i)}"
end

def reg_matcher(regex, string)
  regex.match(string)[0].split[1]
end

def load_average
  file = File.new('/proc/loadavg').read.split
  print "Load Average:\t"
  file.each_with_index do |data, index|
    printf '%5s', data
    break if index == 2
  end
  puts
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

memory
uptime
processes
load_average
