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
      ranges = fetch_index
      fetch_grib2(ranges)
    end

    def fetch_index
      begin
        res = Excon.get("#{url}.idx")
      rescue Excon::Errors::Error
        raise "Download of '#{url}.idx' failed"
      end

      lines = res.body.lines
      lines.each_index.reduce([]) do |r, i|
        records = Forecaster.configuration.records
        if records.values.any? { |record| lines[i].include?(record) }
          first = lines[i].split(":")[1].to_i
          last = ""

          j = i
          while (j += 1) < lines.count
            last = lines[j].split(":")[1].to_i - 1
            break if last != first - 1
          end

          r << "#{first}-#{last}" # Range header syntax
        else
          r
        end
      end
    end

    def fetch_grib2(ranges, progress_block: nil)
      FileUtils.mkpath(dirname)
      path = File.join(dirname, filename)

      streamer = lambda do |chunk, remaining, total|
        File.open(path, "ab") { |f| f.write(chunk) }
        progress_block.call(total - remaining, total) if progress_block
      end

      headers = { "Range" => "bytes=#{ranges.join(',')}" }
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
