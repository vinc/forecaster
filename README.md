Forecaster
==========

Ruby wrapper around `curl` and `wgrib2` to fetch and read data from the Global
Forecast System (GFS).


Installation
------------

    $ gem install forecaster

Alternatively you can build the gem from its repository:

    $ git clone git://github.com/vinc/forecaster.git
    $ cd forecaster
    $ gem build forecaster.gemspec
    $ gem install forecaster-0.0.2.gem

In both cases you need to make sure that you have `curl` and `wgrib2` present
on your system.

To install the later:

    $ curl -o wgrib2.tgz http://www.ftp.cpc.ncep.noaa.gov/wd51we/wgrib2/wgrib2.tgz
    $ tar -xzvf wgrib2.tgz
    $ cd grib2
    $ export CC=gcc
    $ export FC=gfortran
    $ make
    $ sudo cp wgrib2/wgrib2 /usr/local/bin/

Usage
-----

```ruby
require "forecaster"
```

Configure the gem:

```ruby
Forecaster.configure do |config|
  config.cache_dir = "/tmp/forecaster"
  config.curl_path = "/usr/bin/curl"
  config.wgrib2_path = "/usr/local/bin/wgrib2"
end
```

Fetch a forecast:

```ruby
y = 2015 # year of GFS run
m = 5    # month of GFS run
d = 4    # day of GFS run
c = 12   # hour of GFS run
h = 3    # hour of forecast
forecast = Forecaster.fetch(y, m, d, c, h) # Forecaster::Forecast
```

Read a [record][1] of a forecast:

```ruby
key = :prate
value = forecast.read(key, longitude: 48.1147, latitude: -1.6794) # "0.000163"
```

[1]: http://www.nco.ncep.noaa.gov/pmb/products/gfs/gfs_upgrade/gfs.t06z.pgrb2.0p25.f006.shtml


License
-------

Copyright (C) 2015 Vincent Ollivier. Released under MIT.
