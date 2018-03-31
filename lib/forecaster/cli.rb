require "yaml/store"
require "trollop"
require "chronic"
require "timezone"
require "geocoder"
require "ruby-progressbar"
require "rainbow"

require "forecaster"

# Fetch and read data from the Global Forecast System.
module Forecaster
  # Command line interface printing the forecast for a time and a location.
  class CLI
    include Singleton # TODO: Find how best to organize CLI class

    def self.start(args, env)
      instance.start(args, env)
    end

    def initialize
      @store = nil
    end

    def start(args, env)
      opts = parse(args)

      configure(opts)

      cache_file = File.join(Forecaster.configuration.cache_dir, "forecast.yml")
      @store = YAML::Store.new(cache_file)

      puts Rainbow("GFS Weather Forecast").bright
      puts

      lat, lon = get_location(opts, env)

      Trollop.die("Could not parse location") if lat.nil? || lon.nil?

      ENV["TZ"] = get_timezone(lat, lon, env) || env["TZ"]
      time = get_time(opts)
      forecast = get_forecast(time, opts)
      print_forecast(forecast, lat, lon)
      ENV["TZ"] = env["TZ"] # Restore TZ
    end

    # Parse command line options
    def parse(args)
      opts = Trollop.options(args) do
        usage           "for <time> in <location>"
        version         "Forecaster v#{Forecaster::VERSION}"
        opt :time,      "Set time in any format",  :type => String
        opt :location,  "Set location name",       :type => String
        opt :latitude,  "Set latitude in degree",  :type => Float, :short => "a"
        opt :longitude, "Set longitude in degree", :type => Float, :short => "o"
        opt :cache,     "Set cache directory",     :default => "/tmp/forecaster"
        opt :debug,     "Enable debug mode"
      end

      cmd_opts = { :time => [], :location => [] }
      key = :time
      args.each do |word|
        case word
        when "for"
          key = :time
        when "in"
          key = :location
        else
          cmd_opts[key] << word
        end
      end
      opts[:time] ||= cmd_opts[:time].join(" ")
      opts[:location] ||= cmd_opts[:location].join(" ")

      opts
    end

    # Configure gem
    def configure(opts)
      Forecaster.configure do |config|
        config.cache_dir = opts[:cache]
        config.records = {
          :prate => ":PRATE:surface:",
          :pres  => ":PRES:surface:",
          :rh    => ":RH:2 m above ground:",
          :tmp   => ":TMP:2 m above ground:",
          :ugrd  => ":UGRD:10 m above ground:",
          :vgrd  => ":VGRD:10 m above ground:",
          :tcdc  => ":TCDC:entire atmosphere:"
        }
      end
      FileUtils.mkpath(Forecaster.configuration.cache_dir)
    end

    # Get location
    def get_location(opts, env)
      if (opts[:location] || "").length > 0
        @store.transaction do
          if opts[:debug]
            putf_debug("Geolocalizing", opts[:location], "'%s'")
          end

          key = "geocoder:#{opts[:location]}"
          lat, lon = @store[key] ||= geolocalize(opts[:location])

          if opts[:debug]
            if lat && lon
              putf_debug("Location", lat, "%05.2f, %05.2f", optional: lon)
            else
              puts Rainbow("Location not found").red
            end
            puts
          end

          [lat, lon]
        end
      elsif opts[:latitude] && opts[:longitude]
        [opts[:latitude], opts[:longitude]]
      else
        [env["FORECAST_LATITUDE"], env["FORECAST_LONGITUDE"]]
      end
    end

    # Get timezone
    def get_timezone(lat, lon, env)
      tz = nil
      if env["GEONAMES_USERNAME"]
        Timezone::Lookup.config(:geonames) do |config|
          config.username = env["GEONAMES_USERNAME"]
        end
        @store.transaction do
          key = "timezone:#{lat}:#{lon}"
          tz = @store[key] || @store[key] = Timezone.lookup(lat, lon).name
        end
      end

      tz
    end

    # Get time
    def get_time(opts)
      if opts[:time]
        # TODO: Look for a timestamp first
        time = Chronic.parse(opts[:time])
        Trollop.die(:time, "could not be parsed") if time.nil?
        time.utc
      else
        Time.now.utc
      end
    end

    # Get forecast
    def get_forecast(time, opts)
      forecast = Forecast.at(time)

      if opts[:debug]
        putf_debug("Requested time", time.localtime,              "%s")
        putf_debug("GFS run time",   forecast.run_time.localtime, "%s")
        putf_debug("Forecast time",  forecast.time.localtime,     "%s")
        puts
      end

      unless forecast.fetched?
        if opts[:debug]
          putf_debug("Downloading", forecast.url, "'%s'")

          putf_debug("Reading index file",  "", "")
          records = Forecaster.configuration.records.values
          ranges = forecast.fetch_ranges
          ranges = records.map { |k| ranges[k] } # Filter ranges

          filesize = ranges.reduce(0) do |acc, (first, last)|
            acc + last - first # FIXME: `last == nil` on last range of index file
          end
          n = (filesize.to_f / (1 << 20)).round(2)
          putf_debug("Length", filesize, "%d (%.2fM)", optional: n)
          puts

          progressbar = ProgressBar.create(
            :format => "%p%% [%b>%i] %r KB/s %e",
            :rate_scale => lambda { |rate| rate / 1024 }
          )

          progress_block = lambda do |progress, total|
            progressbar.total = total
            progressbar.progress = progress
          end

          forecast.fetch_grib2(ranges, :progress_block => progress_block)

          progressbar.finish
          puts
        else
          forecast.fetch # That's a lot easier ^^
        end
      end

      forecast
    end

    # Print forecast
    def print_forecast(forecast, lat, lon)
      putf("Date", forecast.time.localtime.strftime("%Y-%m-%d"), "%s")
      putf("Time", forecast.time.localtime.strftime("%T"),       "%s")
      putf("Zone", forecast.time.localtime.strftime("%z"),       "%s")

      # Coordinates rounded to the precision of the GFS model
      putf("Latitude",  (lat / 0.25).round / 4.0, "%05.2f °")
      putf("Longitude", (lon / 0.25).round / 4.0, "%05.2f °")
      puts

      tmp   = forecast.read(:tmp,   :latitude => lat, :longitude => lon).to_f
      ugrd  = forecast.read(:ugrd,  :latitude => lat, :longitude => lon).to_f
      vgrd  = forecast.read(:vgrd,  :latitude => lat, :longitude => lon).to_f
      prate = forecast.read(:prate, :latitude => lat, :longitude => lon).to_f
      rh    = forecast.read(:rh,    :latitude => lat, :longitude => lon).to_f
      tcdc  = forecast.read(:tcdc,  :latitude => lat, :longitude => lon).to_f
      pres  = forecast.read(:pres,  :latitude => lat, :longitude => lon).to_f

      temperature    = tmp - 273.15
      wind_direction = (270 - Math.atan2(ugrd, vgrd) * 180 / Math::PI) % 360
      wind_speed     = Math.sqrt(ugrd**2 + vgrd**2)
      precipitation  = prate * 3600
      humidity       = rh
      cloud_cover    = tcdc
      pressure       = pres / 100.0

      wdir = compass_rose(wind_direction)

      putf("Temperature",   temperature,   "%.0f °C")
      putf("Wind",          wind_speed,    "%.1f m/s (%s)", optional: wdir)
      putf("Precipitation", precipitation, "%.1f mm")
      putf("Humidity",      humidity,      "%.0f %")
      putf("Cloud Cover",   cloud_cover,   "%.0f %")
      putf("Pressure",      pressure,      "%.0f hPa")
    end

    def putf(name, value, fmt, optional: "", color: :cyan)
      left_column = Rainbow(format("  %-20s", name)).color(color)
      right_column = Rainbow(format(fmt, value, optional))
      puts "#{left_column} #{right_column}"
    end

    def putf_debug(name, value, fmt, optional: "")
      putf(name, value, fmt, optional: optional, color: :yellow)
    end

    def compass_rose(degree)
      case degree
      when   0...45  then "N"
      when  45...90  then "NE"
      when  90...135 then "E"
      when 135...180 then "SE"
      when 180...225 then "S"
      when 225...270 then "SW"
      when 270...315 then "W"
      else                "NW"
      end
    end

    def geolocalize(location)
      Geocoder.configure(:timeout => 10)
      res = Geocoder.search(location).first
      [res.latitude, res.longitude] if res
    end
  end
end
