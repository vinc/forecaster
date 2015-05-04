Forecaster
==========

Ruby wrapper around `curl` and `wgrib2` to fetch and read data from the Global
Forecast System (GFS).


Installation
------------

    $ gem install forecaster


Usage
-----

    require "forecaster"

Configure the gem:

    Forecaster.configure do |config|
      config.cache_dir = "/tmp/forecaster"
    end

Fetch a forecast:

    y = 2015 # year of GFS run
    m = 5    # month of GFS run
    d = 4    # day of GFS run
    c = 12   # hour of GFS run
    h = 3    # hour of forecast
    forecast = Forecaster.fetch(y, m, d, c, h) # Forecaster::Forecast

Read a [record][1] of a forecast:

    key = :prate
    value = forecast.read(key, longitude: 48.1147, latitude: -1.6794) # "0.000163"

[1]: http://www.nco.ncep.noaa.gov/pmb/products/gfs/gfs_upgrade/gfs.t06z.pgrb2.0p25.f006.shtml


License
-------

Copyright (C) 2015 Vincent Ollivier. Released under MIT.
