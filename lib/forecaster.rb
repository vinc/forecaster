require "forecaster/configuration"
require "forecaster/forecast"

module Forecaster
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Forecaster::Configuration.new
    yield(configuration)
  end

  def self.fetch(year, month, day, hour_of_run, hour_of_forecast)
    Forecaster::Forecast.new(year, month, day, hour_of_run, hour_of_forecast).fetch
  end
end
