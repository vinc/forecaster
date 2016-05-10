module Forecaster
  class Configuration
    attr_accessor :server, :cache_dir, :curl_path, :wgrib2_path, :records

    def initialize
      @server = "http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod"
      @cache_dir = "/tmp/forecaster"
      @curl_path = "curl"
      @wgrib2_path = "wgrib2"
      @records = {
        prate: "PRATE:surface",
        tmp:   "TMP:2 m above ground",
        ugrd:  "UGRD:10 m above ground",
        vgrd:  "VGRD:10 m above ground",
        tcdc:  "TCDC:entire atmosphere"
      }
    end

    def self.configure(options)
      options.each do |option, value|
        self[option] = value
      end
    end
  end
end
