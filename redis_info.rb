class RedisInfo < Scout::Plugin
  def build_report
    cmd  = option(:redis_info_command) || "redis-cli info"
    data = `#{cmd} 2>&1`
    if $?.success?
      stats = parse_data(data)
      report(stats)
      stats.each do |name, total|
        short_name = name.sub(/_total\z/, "")
        max        = option("max_#{short_name}").to_f
        next unless max.nonzero?
        num        = total.to_f
        mem_name   = "#{name}_failure"
        human_name = short_name.capitalize.
                                gsub(/_([a-z])/) { " #{$1.capitalize}"}.
                                gsub("Vms", "VMS")
        if num > max and not memory(mem_name)
          alert "Maximum #{human_name} Exceeded (#{total})", ''
          remember(mem_name => true)
        elsif num < max and memory(mem_name)
          alert "Maximum #{human_name} Has Dropped Below Limit (#{total})", ''
          memory.delete(mem_name)
        else
          remember(mem_name => memory(mem_name))
        end
      end
    else
      error "Could not get data from command", "Error:  #{data}"
    end
  end

  private

  def parse_data(data)
    stats        = { "redis_version"              => 0.0,
                     "uptime_in_seconds"          => 0,
                     "uptime_in_days"             => 0,
                     "connected_clients"          => 0,
                     "connected_slaves"           => 0,
                     "used_memory"                => 0,
                     "changes_since_last_save"    => 0,
                     "bgsave_in_progress"         => 0,
                     "last_save_time"             => 0,
                     "total_connections_received" => 0,
                     "total_commands_processed"   => 0,
                     "role"                       => "None" }

    data.each do |line|
      values = line.split(':')
      if values.size == 2
        values[0].strip!
        values[1].strip!
        if values[0] =~ /.*_time$/
          values[1] = Time.at(values[1].to_i).strftime('%Y-%m-%d %H:%M:%S')
        elsif values[0] =~ /.*_memory$/
          values[1] = "#{as_mb(values[1])}"
        end
        stats["#{values[0]}"] = values[1]
      end
    end

    stats
  end

  KILO = 1024.to_i
  MEGA = (1024 * 1024).to_i
  GIGA = (1024 * 1024 * 1024).to_i

  def as_mb(memory_string)
    num = memory_string.to_i
    if num < KILO
      "#{num} B"
    elsif num < MEGA
      "#{num / KILO} KB"
    elsif num < GIGA
      "#{num / MEGA} MB"
    else
      "#{num / GIGA} GB"
    end
  end

end
