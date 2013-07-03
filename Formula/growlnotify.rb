require 'formula'

class GrowlHelperAppRequirement < Requirement
  GROWL_HELPER_BUNDLE_ID = "com.Growl.GrowlHelperApp"
  attr_reader :min_version

  fatal true

  def initialize(version = "2.0", tags = [])
    # Extract the min_version if given. Default to GrowlHelperApp 2.x
    if /(\d+\.)*\d+/ === version.to_s
      @min_version = Version.new(version)
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
        Version.new(`mdls -raw -name kMDItemVersion "#{path}" 2>/dev/null`.strip)
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

  def install
    safe_system '/usr/sbin/pkgutil', '--expand', 'GrowlNotify.pkg', "#{name}_extracted"
    chdir "#{name}_extracted"

    # We have growlnotify.pkg and growlnotify-1.pkg
    Dir['*.pkg'].each do |package|
      safe_system "/bin/pax", "--insecure", "-rz", "-f", "#{package}/Payload"
    end
    bin.install 'growlnotify'
    man1.install 'growlnotify.1'

    doc.install Dir['Resources/*/{License,ReadMe}']
  end

  test do
    system "#{bin}/growlnotify", "--version"
  end
end
