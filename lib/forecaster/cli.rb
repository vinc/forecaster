require "yaml/store"
require "trollop"
require "chronic"
require "timezone"
require "geocoder"
require "ruby-progressbar"

require "forecaster"

# Fetch and read data from the Global Forecast System.
module Forecaster
  # Command line interface printing the forecast for a time and a location.
  class CLI
    include Singleton # TODO: Find how best to organize CLI class

    FORECAST_FORMAT = "  %-15s % 7.1f %s".freeze

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

      puts "GFS Weather Forecast"
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
      if opts[:location]
        @store.transaction do
          if opts[:debug]
            puts format("%-15s '%s'", "Geolocalizing:", opts[:location])
          end

          key = "geocoder:#{opts[:location]}"
          lat, lon = @store[key] ||= geolocalize(opts[:location])

          if opts[:debug]
            if lat && lon
              puts format("%-15s %s, %s", "Found:", lat, lon)
            else
              puts "Not found"
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
        puts format("%-15s %s", "Requested time:", time.localtime)
        puts format("%-15s %s", "GFS run time:", forecast.run_time.localtime)
        puts format("%-15s %s", "Forecast time:", forecast.time.localtime)
        puts
      end

      unless forecast.fetched?
        if opts[:debug]
          puts "Downloading: '#{forecast.url}'"

          puts "Reading index file..."
          ranges = forecast.fetch_index

          filesize = ranges.reduce(0) do |acc, range|
            first, last = range.split("-").map(&:to_i)
            acc + last - first
          end
          filesize_in_megabytes = (filesize.to_f / (1 << 20)).round(2)
          puts "Length: #{filesize} (#{filesize_in_megabytes}M)"
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
      forecast_time = forecast.time.localtime

      puts format("  %-11s % 11s", "Date:", forecast_time.strftime("%Y-%m-%d"))
      puts format("  %-11s % 11s", "Time:", forecast_time.strftime("%T"))
      puts format("  %-11s % 11s", "Zone:", forecast_time.strftime("%z"))
      puts format(FORECAST_FORMAT, "Latitude:",  lat, "°")
      puts format(FORECAST_FORMAT, "Longitude:", lon, "°")
      puts

      pres  = forecast.read(:pres,  :latitude => lat, :longitude => lon).to_f
      tmp   = forecast.read(:tmp,   :latitude => lat, :longitude => lon).to_f
      ugrd  = forecast.read(:ugrd,  :latitude => lat, :longitude => lon).to_f
      vgrd  = forecast.read(:vgrd,  :latitude => lat, :longitude => lon).to_f
      prate = forecast.read(:prate, :latitude => lat, :longitude => lon).to_f
      rh    = forecast.read(:rh,    :latitude => lat, :longitude => lon).to_f
      tcdc  = forecast.read(:tcdc,  :latitude => lat, :longitude => lon).to_f

      pressure       = pres / 100.0
      temperature    = tmp - 273.15
      wind_speed     = Math.sqrt(ugrd**2 + vgrd**2)
      wind_direction = (270 - Math.atan2(ugrd, vgrd) * 180 / Math::PI) % 360
      precipitation  = prate * 3600
      humidity       = rh
      cloud_cover    = tcdc

      puts format(FORECAST_FORMAT, "Pressure:",       pressure,       "hPa")
      puts format(FORECAST_FORMAT, "Temperature:",    temperature,    "°C")
      puts format(FORECAST_FORMAT, "Wind Speed:",     wind_speed,     "m/s")
      puts format(FORECAST_FORMAT, "Wind Direction:", wind_direction, "°")
      puts format(FORECAST_FORMAT, "Precipitation:",  precipitation,  "mm")
      puts format(FORECAST_FORMAT, "Humidity:",       humidity,       "%")
      puts format(FORECAST_FORMAT, "Cloud Cover:",    cloud_cover,    "%")
    end

    def geolocalize(location)
      Geocoder.configure(:timeout => 10)
      res = Geocoder.search(location).first
      [res.latitude, res.longitude] if res
    end
  end
end
