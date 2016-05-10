Gem::Specification.new do |s|
  s.name        = "forecaster"
  s.version     = "0.0.2"
  s.date        = "2016-06-09"
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
  s.homepage    = "https://github.com/vinc/forecaster"
  s.license     = "MIT"
end
