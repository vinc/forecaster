Forecaster
==========

[![Gem](https://img.shields.io/gem/v/forecaster.svg)](https://rubygems.org/gems/forecaster)
[![Build Status](https://api.travis-ci.org/vinc/forecaster.svg?branch=master)](http://travis-ci.org/vinc/forecaster)
[![Code Climate](https://codeclimate.com/github/vinc/forecaster.svg)](https://codeclimate.com/github/vinc/forecaster)
[![Code Coverage](https://codecov.io/gh/vinc/forecaster/branch/master/graph/badge.svg)](https://codecov.io/gh/vinc/forecaster)
[![Gemnasium](https://img.shields.io/gemnasium/vinc/forecaster.svg)](https://gemnasium.com/github.com/vinc/forecaster)

[Forecaster](https://github.com/vinc/forecaster) is a gem wrapping `wgrib2` to
fetch and read weather data directly from the Global Forecast System.

It comes with a library and a CLI allowing you to type commands like `forecast
for this afternoon in paris` in your terminal to get the latest weather
forecast.

[![asciicast](https://asciinema.org/a/146117.png)](https://asciinema.org/a/146117)


Installation
------------

```bash
gem install forecaster
```

Alternatively you can build the gem from its repository:

```bash
git clone git://github.com/vinc/forecaster.git
cd forecaster
gem build forecaster.gemspec
gem install forecaster-1.0.0.gem
```

In both cases you need to make sure that you have `wgrib2` present in your
system.

To install the `wgrib2` from source:

```bash
wget http://www.ftp.cpc.ncep.noaa.gov/wd51we/wgrib2/wgrib2.tgz
tar -xzvf wgrib2.tgz
cd grib2
export CC=gcc
export FC=gfortran
make
sudo cp wgrib2/wgrib2 /usr/local/bin/
```

Usage
-----

```ruby
require "forecaster"
```

To configure the gem:

```ruby
Forecaster.configure do |config|
  config.wgrib2_path = "/usr/local/bin/wgrib2"
  config.cache_dir = "/tmp/forecaster"
  config.records = {
    :temperature => ":TMP:2 m above ground:",
    :humidity    => ":RH:2 m above ground:",
    :pressure    => ":PRES:surface:"
  }
end
```

Forecaster saves large files containing the data of GFS runs from the NOAA
servers in the cache directory, but only the parts of the files containing
the records defined in the configuration will be downloaded.

You can find the list of available records [online][1] or by reading any
`.idx` files distributed along with the GFS files.

A record is identified by a variable and a layer separated by colon
characters. In the case of the temperature for example, those attributes
are `TMP` and `2 m above ground`. See the [documentation of wgrib2][2] for
more information.

To fetch a forecast:

```ruby
t = Time.now.utc # All the dates should be expressed in UTC
y = t.year       # year of GFS run
m = t.month      # month of GFS run
d = t.day        # day of GFS run
c = 0            # hour of GFS run (must be a multiple of 6)
h = 12           # hour of forecast (must be a multiple of 3)
forecast = Forecaster.fetch(y, m, d, c, h) # Forecaster::Forecast
```

To read the [record][1] of a forecast:

```ruby
res = forecast.read(:temperature, longitude: 48.1147, latitude: -1.6794) # String in Kelvin
val = res.to_f - 273.15 # Float in degree Celsius
```

[1]: http://www.nco.ncep.noaa.gov/pmb/products/gfs/gfs_upgrade/gfs.t06z.pgrb2.0p25.f006.shtml
[2]: http://www.cpc.ncep.noaa.gov/products/wesley/wgrib2/


Command line
------------

Forecaster has a command line tool that try to be smart:

    $ forecast for tomorrow afternoon in auckland
    GFS Weather Forecast

      Date:        2016-05-13
      Time:          12:00:00
      Zone:             +1200
      Latitude:         -36.8 °
      Longitude:        174.8 °

      Pressure:        1013.8 hPa
      Temperature:       21.7 °C
      Wind Direction:   163.5 °
      Wind Speed:         8.0 m/s
      Precipitation:      0.0 mm
      Humidity:          65.1 %
      Cloud Cover:        0.0 %

But you can use it in a more verbose way:

    $ TZ=America/Los_Angeles forecast --time "2016-05-12 09:00:00" \
                                      --latitude "37.7749295" \
                                      --longitude "-122.4194155" \
                                      --debug
    Requested time:  2016-05-12 09:00:00 -0700
    GFS Run time:    2016-05-11 23:00:00 -0700
    Forecast time:   2016-05-12 08:00:00 -0700

    Downloading: 'http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gfs.20160
    51200/gfs.t00z.pgrb2.0p25.f015'
    Reading index file...
    Length: 4992281 (4.76M)

    100% [===========================================>] 696 KB/s Time: 00:00:07

    GFS Weather Forecast

      Date:        2016-05-12
      Time:          08:00:00
      Zone:             -0700
      Latitude:          37.8 °
      Longitude:       -122.4 °

      Pressure:        1013.5 hPa
      Temperature:       13.4 °C
      Wind Direction:   167.3 °
      Wind Speed:         1.0 m/s
      Precipitation:      0.0 mm
      Humidity:          89.7 %
      Cloud Cover:        0.0 %

To use automatically the timezone of a location you will need to create
a free [GeoNames account][3] and export your username in an environment
variable:

    export GEONAMES_USERNAME=<username>

And while you're doing that, you can also export your favorite location
to avoid typing it every time:

    export FORECAST_LATITUDE=<latitude>
    export FORECAST_LONGITUDE=<longitude>

[3]: http://www.geonames.org/login


License
-------

Copyright (c) 2015-2018 Vincent Ollivier. Released under MIT.
