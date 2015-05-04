require "tmpdir"
require "fileutils"

RSpec.describe Forecaster::Forecast do
  before do
    Forecaster.configure do |config|
      config.cache_dir = Dir.mktmpdir
    end

    t = Time.now - 86400
    y = t.year
    m = t.month
    d = t.day
    c = 0 # hour of GFS run
    h = 3 # hour of forecast
    @forecast = Forecaster::Forecast.new(y, m, d, c, h)
  end

  after do
    FileUtils.remove_entry_secure(Forecaster.configuration.cache_dir)
  end

  it "fetches a forecast" do
    expect(@forecast.fetched?).to be false
    @forecast.fetch
    expect(@forecast.fetched?).to be true
  end

  it "reads a forecast" do
    @forecast.fetch
    value = @forecast.read(:prate, longitude: 48.1147, latitude: -1.6794)
    expect(value).to be_a(String)
  end
end
