require "fileutils"
require "excon"

# Fetch and read data from the Global Forecast System.
module Forecaster
  # Fetch and read a specific forecast from a GFS run.
  #
  # See: http://www.nco.ncep.noaa.gov/pmb/products/gfs/
  class Forecast
    def self.last_run_at
      # There is a new GFS run every 6 hours starting at midnight UTC, and it
      # takes approximately 3 to 5 hours before a run is available online, so
      # to be on the safe side we return the previous one.
      now = Time.now.utc
      run = Time.new(now.year, now.month, now.day, (now.hour / 6) * 6)

      run - 6 * 3600
    end

    def self.at(time)
      # There is a forecast every 3 hours after a run for 384 hours.
      t = time.utc
      fct = Time.new(t.year, t.month, t.day, (t.hour / 3) * 3)
      run = Time.new(t.year, t.month, t.day, (t.hour / 6) * 6)
      run -= 6 * 3600 if run == fct

      last_run = Forecast.last_run_at
      run = last_run if run > last_run

      fct_hour = (fct - run) / 3600

      raise "Time too far in the future" if fct_hour > 384

      Forecast.new(run.year, run.month, run.day, run.hour, fct_hour)
    end

    def initialize(year, month, day, run_hour, fct_hour)
      @year = year
      @month = month
      @day = day
      @run_hour = run_hour
      @fct_hour = fct_hour
    end

    def run_time
      Time.utc(@year, @month, @day, @run_hour)
    end

    def time
      run_time + @fct_hour * 3600
    end

    def dirname
      subdir = format("%04d%02d%02d%02d", @year, @month, @day, @run_hour)
      File.join(Forecaster.configuration.cache_dir, subdir)
    end

    def filename
      format("gfs.t%02dz.pgrb2.0p25.f%03d", @run_hour, @fct_hour)
    end

    def url
      server = Forecaster.configuration.server
      subdir = format("gfs.%04d%02d%02d%02d", @year, @month, @day, @run_hour)
      format("%s/%s/%s", server, subdir, filename)
    end

    def fetched?
      File.exist?(File.join(dirname, filename))
    end

    # This method will save the forecast file in the cache directory.
    # But only the parts of the file containing the fields defined in
    # the configuration will be downloaded.
    def fetch
      return if fetched?

      ranges = fetch_ranges

      # Select which byte ranges to download
      records = Forecaster.configuration.records.values
      filtered_ranges = records.map { |k| ranges[k] }

      fetch_grib2(filtered_ranges)
    end

    # Fetch the index file of a GRIB2 file containing the data of a forecast.
    #
    # Returns a hashmap of every records in the file with their byte ranges.
    #
    # With this method we can avoid downloading unnecessary parts of the GRIB2
    # file by matching the records defined in the configuration. It can also
    # be used to set up the later.
    def fetch_ranges
      begin
        res = Excon.get("#{url}.idx")
      rescue Excon::Errors::Error
        raise "Download of '#{url}.idx' failed"
      end
      lines = res.body.lines.map { |line| line.split(":") }
      lines.each_index.each_with_object({}) do |i, ranges|
        # A typical line (before the split on `:`) looks like this:
        # `12:4593854:d=2016051118:TMP:2 mb:9 hour fcst:`
        line = lines[i]
        next_line = lines[i + 1] # NOTE: Will be `nil` on the last line

        # The fourth and fifth fields constitue the key to identify the records
        # defined in `Forecaster::Configuration`.
        key = ":#{line[3]}:#{line[4]}:"

        # The second field is the first byte of the record in the GRIB2 file.
        ranges[key] = [line[1].to_i]

        # To get the last byte we need to read the next line.
        # If we are on the last line we won't be able to get the last byte,
        # but we don't need it according to the section 14.35.1 Byte Ranges
        # of RFC 2616.
        ranges[key] << next_line[1].to_i - 1 if next_line
      end
    end

    def fetch_grib2(ranges, progress_block: nil)
      FileUtils.mkpath(dirname)
      path = File.join(dirname, filename)

      streamer = lambda do |chunk, remaining, total|
        File.open(path, "ab") { |f| f.write(chunk) }
        progress_block.call(total - remaining, total) if progress_block
      end

      byte_ranges = ranges.map { |r| r.join("-") }.join(",")
      headers = { "Range" => "bytes=#{byte_ranges}" }

      begin
        Excon.get(url, :headers => headers, :response_block => streamer)
      rescue Excon::Errors::Error => e
        File.delete(path)
        raise "Download of '#{url}' failed: #{e}"
      end
    end

    def read(field, latitude: 0.0, longitude: 0.0)
      wgrib2 = Forecaster.configuration.wgrib2_path
      record = Forecaster.configuration.records[field]
      path = File.join(dirname, filename)

      raise "'#{path}' not found" unless File.exist?(path)

      coords = "#{longitude} #{latitude}"
      output = `#{wgrib2} #{path} -lon #{coords} -match "#{record}"`

      raise "Could not read '#{record}' in '#{path}'" if output.empty?

      fields = output.split("\n").first.split(":")
      params = Hash[*fields.last.split(",").map { |s| s.split("=") }.flatten]

      params["val"]
    end
  end
end
