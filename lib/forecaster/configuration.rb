# Fetch and read data from the Global Forecast System.
module Forecaster
  # Configure how to fetch and read from a forecast file.
  class Configuration
    attr_accessor :server, :cache_dir, :curl_path, :wgrib2_path, :records

    def initialize
      @server = "https://ftp.ncep.noaa.gov/data/nccf/com/gfs/prod"
      @cache_dir = "/tmp/forecaster"
      @wgrib2_path = "wgrib2"

      # See: http://www.nco.ncep.noaa.gov/pmb/products/gfs/gfs_upgrade/gfs.t06z.pgrb2.0p25.f006.shtml
      # See: http://www.cpc.ncep.noaa.gov/products/wesley/wgrib2/
      # Use `variable` and `level` attributes separated by colons to identify
      # the records to download and read.
      @records = {
        :prate => ":PRATE:surface:",
        :tmp   => ":TMP:2 m above ground:",
        :ugrd  => ":UGRD:10 m above ground:",
        :vgrd  => ":VGRD:10 m above ground:",
        :tcdc  => ":TCDC:entire atmosphere:"
      }
    end

    def self.configure(options)
      options.each do |option, value|
        self[option] = value
      end
    end
  end
end
