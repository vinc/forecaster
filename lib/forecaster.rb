require "forecaster/configuration"
require "forecaster/forecast"
require "forecaster/version"
require "forecaster/cli"

# Fetch and read data from the Global Forecast System.
module Forecaster
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Forecaster::Configuration.new
    yield(configuration)
  end

  def self.fetch(year, month, day, hour_of_run, hour_of_forecast)
    y = year
    m = month
    d = day
    c = hour_of_run
    h = hour_of_forecast
    forecast = Forecaster::Forecast.new(y, m, d, c, h)
    forecast.fetch
    forecast
  end
end
