Forecaster
==========

Ruby wrapper around `wgrib2` to fetch and read data from the Global Forecast
System (GFS).


Installation
------------

    $ gem install forecaster

Alternatively you can build the gem from its repository:

    $ git clone git://github.com/vinc/forecaster.git
    $ cd forecaster
    $ gem build forecaster.gemspec
    $ gem install forecaster-0.0.2.gem

In both cases you need to make sure that you have `wgrib2` present in your
system.

To install the later:

    $ wget http://www.ftp.cpc.ncep.noaa.gov/wd51we/wgrib2/wgrib2.tgz
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


License
-------

Copyright (C) 2015 Vincent Ollivier. Released under MIT.
