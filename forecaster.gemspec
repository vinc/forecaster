lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "forecaster/version"

Gem::Specification.new do |s|
  s.name        = "forecaster"
  s.version     = Forecaster::VERSION
  s.license     = "MIT"
  s.summary     = "Wrapper around wgrib2 to read data from the GFS"
  s.description = "Wrapper around wgrib2 to read data directly from the Global Forecast System"
  s.homepage    = "https://github.com/vinc/forecaster"
  s.email       = "v@vinc.cc"
  s.authors     = [
    "Vincent Ollivier"
  ]
  s.files       = Dir.glob("{bin,lib}/**/*.rb") + %w[LICENSE README.md CHANGELOG.md]
  s.executables << "forecast"
  s.add_runtime_dependency("chronic",          "~> 0.10", ">= 0.10.0")
  s.add_runtime_dependency("excon",            "~> 0.49", ">= 0.49.0")
  s.add_runtime_dependency("geocoder",         "~> 1.3",  ">= 1.3.0")
  s.add_runtime_dependency("optimist",         "~> 3.0",  ">= 3.0.0")
  s.add_runtime_dependency("rainbow",          "~> 3.0",  ">= 3.0.0")
  s.add_runtime_dependency("ruby-progressbar", "~> 1.8",  ">= 1.8.0")
  s.add_runtime_dependency("timezone",         "~> 1.2",  ">= 1.2.0")
  s.add_development_dependency("codecov",      "~> 0.1",  ">= 0.1.10")
  s.add_development_dependency("rspec",        "~> 3.7",  ">= 3.7.0")
  s.add_development_dependency("simplecov",    "~> 0.16", ">= 0.16.1")
  s.add_development_dependency("timecop",      "~> 0.9",  ">= 0.9.0")
end
