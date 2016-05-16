require "tmpdir"
require "fileutils"
require "timecop"

RSpec.describe Forecaster do
  before do
    Forecaster.configure do |config|
      config.cache_dir = Dir.mktmpdir
      config.records = {
        :tmp => ":TMP:2 m above ground:" # Temperature
      }
    end

    t = Time.now - 86_400
    @y = t.year
    @m = t.month
    @d = t.day
    @c = 0 # hour of GFS run
    @h = 3 # hour of forecast
  end

  after do
    FileUtils.remove_entry_secure(Forecaster.configuration.cache_dir)
  end

  it "requires wgrib2" do
    wgrib2_path = Forecaster.configuration.wgrib2_path
    out = `#{wgrib2_path} -version`

    expect(out).to start_with("v0.2")
  end

  it "fetches a forecast" do
    forecast = Forecaster.fetch(@y, @m, @d, @c, @h)

    expect(forecast.fetched?).to be true
  end

  describe Forecaster::Forecast do
    it "gets the time of the last GFS run" do
      # There are 4 GFS runs per day at 0h, 6h, 12h and 18h UTC.
      # They are available online 6 hours after the run.
      # See: http://www.nco.ncep.noaa.gov/pmb/products/gfs/

      t = Time.new(2015, 1, 1, 0, 0).utc
      Timecop.freeze(t + 7 * 3600) do
        expect(Forecaster::Forecast.last_run_at).to eq(t)
      end
      Timecop.freeze(t + 13 * 3600) do
        expect(Forecaster::Forecast.last_run_at).to eq(t + 6 * 3600)
      end
    end

    it "create a forecast" do
      t = Time.new(2015, 1, 1, 0, 0).utc
      Timecop.freeze(t + 7 * 3600) do
        # There is a forecast every 3 hours after a run for 384 hours.
        # See: http://www.nco.ncep.noaa.gov/pmb/products/gfs/

        #
        # Forecasts from an archived run
        #

        # exactly at the time of a forecast
        forecast = Forecaster::Forecast.at(t)
        expect(forecast.run_time).to eq(t - 6 * 3600)
        expect(forecast.time).to eq(t)

        # 1 hour after a forecast time
        forecast = Forecaster::Forecast.at(t + 1 * 3600)
        expect(forecast.run_time).to eq(t - 6 * 3600)
        expect(forecast.time).to eq(t)

        #
        # Forecasts from the last run
        #

        # exactly at the time of a forecast
        forecast = Forecaster::Forecast.at(t + 6 * 3600)
        expect(forecast.run_time).to eq(t)
        expect(forecast.time).to eq(t + 6 * 3600)

        # 1 hour after a forecast time
        forecast = Forecaster::Forecast.at(t + 4 * 3600)
        expect(forecast.run_time).to eq(t)
        expect(forecast.time).to eq(t + 3 * 3600)

        # 1 hour after a forecast time
        forecast = Forecaster::Forecast.at(t + 10 * 3600)
        expect(forecast.run_time).to eq(t)
        expect(forecast.time).to eq(t + 9 * 3600)

        # 1 hour after a forecast time
        forecast = Forecaster::Forecast.at(t + 49 * 3600)
        expect(forecast.run_time).to eq(t)
        expect(forecast.time).to eq(t + 48 * 3600)

        # TODO: Test with a time too far in the future
      end
    end

    it "fetches a forecast" do
      forecast = Forecaster::Forecast.new(@y, @m, @d, @c, @h)

      expect(forecast.fetched?).to be false
      forecast.fetch
      expect(forecast.fetched?).to be true
    end

    it "reads a forecast" do
      forecast = Forecaster::Forecast.new(@y, @m, @d, @c, @h)

      forecast.fetch
      value = forecast.read(:tmp, :longitude => 48.1147, :latitude => -1.6794)
      expect(value).to be_a(String)
      expect(value.to_i).to be_between(180, 340).inclusive # in Kelvin
    end
  end
end
