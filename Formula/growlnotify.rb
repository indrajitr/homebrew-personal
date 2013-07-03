require 'formula'

class GrowlHelperAppRequirement < Requirement
  GROWL_HELPER_BUNDLE_ID = "com.Growl.GrowlHelperApp"
  attr_reader :min_version

  fatal true

  class GrowlHelperAppVersion < Version
    def major
      tokens[0].to_s.to_i
    end
    def minor
      tokens[1].to_s.to_i
    end
  end

  def initialize(version="2.0", tags=[])
    # Extract the min_version if given. Default to GrowlHelperApp 2.x
    if /(\d+\.)*\d+/ === version.to_s
      @min_version = GrowlHelperAppVersion.new(version)
    else
      raise "Invalid version specification for GrowlHelperApp: '#{version}'"
    end
    super tags
  end

  satisfy :build_env => false do
    helper_version ||= begin
      # Ask Spotlight where GrowlHelperApp is
      path = MacOS.app_with_bundle_id(GROWL_HELPER_BUNDLE_ID)
      if not path.nil? and path.exist?
        # And detect version if found
        GrowlHelperAppVersion.new(`mdls -raw -name kMDItemVersion "#{path}" 2>/dev/null`.strip)
      end
    end
    @min_version <= helper_version unless helper_version.nil?
  end

  def message; <<-EOS.undent
    Growl Helper App #{@min_version} or newer is required.
    Install it from the App Store at:
      https://itunes.apple.com/app/growl/id467939042?mt=12
    EOS
  end
end

class Growlnotify < Formula
  homepage 'http://growl.info/downloads#generaldownloads'
  url 'http://growl.cachefly.net/GrowlNotify-2.0.zip'
  sha1 'efd54dec2623f57fcbbba54050206d70bc7746dd'

  depends_on :macos => :lion
  depends_on GrowlHelperAppRequirement.new

  def options
    [['--target=<target_device>', "Install on a different volume, defaults to '/'"]]
  end

  def target_device
    # check arguments for a different target device
    ARGV.each do |a|
      if a.index('--target')
        return a.sub('--target=', '')
      end
    end
    '/'
  end

  def install
    pkg_file = Dir['*.pkg'].first
    mkdir('extracted') do
      safe_system "/usr/bin/xar", "-xf", @buildpath/pkg_file
      # safe_system "pax", "--insecure", "-rz", "-f", payload, "-s", "',.,#{bin},'"
      safe_system "pax", "--insecure", "-rz", "-f", "growlnotify.pkg/Payload"
      bin.install 'growlnotify'
      safe_system "pax", "--insecure", "-rz", "-f", "growlnotify-1.pkg/Payload"
      man1.install 'growlnotify.1'
      doc.install Dir['Resources/*/{License,ReadMe}']
    end
  end

  test do
    system "growlnotify", "--version"
  end
end
