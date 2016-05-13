Gem::Specification.new do |s|
  s.name        = "forecaster"
  s.version     = "0.1.0"
  s.date        = "2016-06-11"
  s.license     = "MIT"
  s.summary     = "Wrapper around curl and wgrib2 to fetch and read GFS data"
  s.description = s.summary
  s.homepage    = "https://github.com/vinc/forecaster"
  s.email       = "v@vinc.cc"
  s.authors     = [
    "Vincent Ollivier"
  ]
  s.files       = [
    "lib/forecaster.rb",
    "lib/forecaster/cli.rb",
    "lib/forecaster/configuration.rb",
    "lib/forecaster/forecast.rb",
    "lib/forecaster/version.rb"
  ]
  s.executables << "forecast"
  s.add_runtime_dependency("excon",            "~> 0.49", ">= 0.49.0")
  s.add_runtime_dependency("trollop",          "~> 2.1",  ">= 2.1.0")
  s.add_runtime_dependency("chronic",          "~> 0.10", ">= 0.10.0")
  s.add_runtime_dependency("timezone",         "~> 0.99", ">= 0.99.0")
  s.add_runtime_dependency("geocoder",         "~> 1.3",  ">= 1.3.0")
  s.add_runtime_dependency("ruby-progressbar", "~> 1.8",  ">= 1.8.0")
end
