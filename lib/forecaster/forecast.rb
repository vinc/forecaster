require "fileutils"

module Forecaster
  class Forecast
    def initialize(year, month, day, hour_of_run, hour_of_forecast)
      @year = year
      @month = month
      @day = day
      @hour_of_run = hour_of_run
      @hour_of_forecast = hour_of_forecast
    end

    def read(field, latitude: 0.0, longitude: 0.0)
      wgrib2_path = Forecaster.configuration.wgrib2_path
      record = Forecaster.configuration.records[field]
      cachename = Forecaster.configuration.cache_dir

      filename = "gfs.t%02dz.pgrb2.0p25.f%03d" % [
        @hour_of_run, @hour_of_forecast
      ]
      pathname = "%04d%02d%02d%02d" % [
        @year, @month, @day, @hour_of_run
      ]
      path = File.join(cachename, pathname, filename)

      raise "'#{path}' not found" unless File.exists?(path)

      out = `#{wgrib2_path} #{path} -lon #{longitude} #{latitude} -match "#{record}"`
      lines = out.split("\n")
      fields = lines.first.split(":")
      params = Hash[*fields.last.split(",").map { |s| s.split("=") }.flatten]

      params["val"]
    end

    def fetched?
      cachename = Forecaster.configuration.cache_dir
      pathname = "%04d%02d%02d%02d" % [
        @year, @month, @day, @hour_of_run
      ]
      filename = "gfs.t%02dz.pgrb2.0p25.f%03d" % [
        @hour_of_run, @hour_of_forecast
      ]
      File.exist?(File.join(cachename, pathname, filename))
    end

    def fetch
      return self if fetched?

      server = Forecaster.configuration.server
      cachename = Forecaster.configuration.cache_dir
      curl_path = Forecaster.configuration.curl_path
      curl = "#{curl_path} -f -s -S"

      pathname = "%04d%02d%02d%02d" % [
        @year, @month, @day, @hour_of_run
      ]
      FileUtils.mkpath(File.join(cachename, pathname))

      filename = "gfs.t%02dz.pgrb2.0p25.f%03d" % [
        @hour_of_run, @hour_of_forecast
      ]
      url = "%s/gfs.%04d%02d%02d%02d/%s" % [
        server, @year, @month, @day, @hour_of_run, filename
      ]
      path = File.join(cachename, pathname, filename)

      # puts "Downloading '#{url}.idx' ..."
      cmd = "#{curl} -o #{path}.idx #{url}.idx"
      return self unless system(cmd)

      lines = IO.readlines("#{path}.idx")
      n = lines.count
      ranges = lines.each_index.reduce([]) do |r, i|
        records = Forecaster.configuration.records
        if records.values.any? { |record| lines[i].include?(record) }
          first = lines[i].split(":")[1].to_i
          last = ""

          j = i
          while (j += 1) < n
            last = lines[j].split(":")[1].to_i - 1
            break if last != first - 1
          end

          r << "#{first}-#{last}" # cURL syntax for a range
        else
          r
        end
      end
      system("rm #{path}.idx")

      # puts "Downloading '#{url}' ..."
      cmd = "#{curl} -r #{ranges.join(",")} -o #{path} #{url}"
      return self unless system(cmd)

      self
    end
  end
end
