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

    def dirname
      subdir = "%04d%02d%02d%02d" % [
        @year, @month, @day, @hour_of_run
      ]
      File.join(Forecaster.configuration.cache_dir, subdir)
    end

    def filename
      "gfs.t%02dz.pgrb2.0p25.f%03d" % [
        @hour_of_run, @hour_of_forecast
      ]
    end

    def url
      server = Forecaster.configuration.server
      "%s/gfs.%04d%02d%02d%02d/%s" % [
        server, @year, @month, @day, @hour_of_run, filename
      ]
    end

    def fetched?
      File.exist?(File.join(dirname, filename))
    end

    # This method will save the forecast file in the cache directory.
    # But only the parts of the file containing the fields defined in
    # the configuration will be downloaded.
    def fetch
      return self if fetched?

      curl = Forecaster.configuration.curl_path

      FileUtils.mkpath(File.join(dirname))

      path = File.join(dirname, filename)

      # puts "Downloading '#{url}.idx' ..."
      cmd = "#{curl} -fsS -o #{path}.idx #{url}.idx"
      raise "Download of '#{url}.idx' failed" unless system(cmd)

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
      cmd = "#{curl} -fsS -r #{ranges.join(",")} -o #{path} #{url}"
      raise "Download of '#{url}' failed" unless system(cmd)

      self
    end

    def read(field, latitude: 0.0, longitude: 0.0)
      wgrib2 = Forecaster.configuration.wgrib2_path
      record = Forecaster.configuration.records[field]
      path = File.join(dirname, filename)

      raise "'#{path}' not found" unless File.exists?(path)

      coords = "#{longitude} #{latitude}"
      output = `#{wgrib2} #{path} -lon #{coords} -match "#{record}"`

      raise "Could not read '#{record}' in '#{path}'" if output.empty?

      fields = output.split("\n").first.split(":")
      params = Hash[*fields.last.split(",").map { |s| s.split("=") }.flatten]

      params["val"]
    end
  end
end
