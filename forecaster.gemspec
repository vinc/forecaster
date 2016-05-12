Gem::Specification.new do |s|
  s.name        = "forecaster"
  s.version     = "0.1.0"
  s.date        = "2016-06-11"
  s.summary     = "Wrapper around curl and wgrib2 to fetch and read GFS data"
  s.description = s.summary
  s.authors     = [
    "Vincent Ollivier"
  ]
  s.email       = "v@vinc.cc"
  s.files       = [
    "lib/forecaster.rb",
    "lib/forecaster/configuration.rb",
    "lib/forecaster/forecast.rb"
  ]
  s.executables << "forecast"
  s.add_runtime_dependency "slop",     "~> 4.3",  ">= 4.3.0"
  s.add_runtime_dependency "chronic",  "~> 0.10", ">= 0.10.0"
  s.add_runtime_dependency "timezone", "~> 0.99", ">= 0.99.0"
  s.add_runtime_dependency "geocoder", "~> 1.3",  ">= 1.3.0"
  s.homepage    = "https://github.com/vinc/forecaster"
  s.license     = "MIT"
end
