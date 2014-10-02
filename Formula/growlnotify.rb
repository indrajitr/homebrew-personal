require 'formula'

class GrowlHelperAppRequirement < Requirement

  GROWL_HELPER_BUNDLE_ID = "com.Growl.GrowlHelperApp"
  GROWL_HELPER_BUNDLE_PATH = Pathname.new("/Applications/Growl.app")
  attr_reader :min_version

  fatal true

  def initialize(version = "2.1", tags = [])
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
      if File.executable? "#{GROWL_HELPER_BUNDLE_PATH}/Contents/MacOS/Growl"
        # Try detecting version directly if it is installed in usual place
        info = "#{GROWL_HELPER_BUNDLE_PATH}/Contents/Info.plist"
        if File.exist? "#{info}"
          Version.new(Utils.popen_read(
            "/usr/bin/defaults", "read", info.to_s, "CFBundleVersion", &:read
          ).strip)
        end
      else
        # Ask Spotlight where Growl is. If the user didn't installed Growl
        # in a non-conventional place, this is our only option.
        # See: http://superuser.com/questions/390757
        path = MacOS.app_with_bundle_id(GROWL_HELPER_BUNDLE_ID)
        if not path.nil? and path.exist?
          Version.new(Utils.popen_read(
            "/usr/bin/mdls", "-raw", "-nullMarker", "", "-name", "kMDItemVersion", path.to_s, &:read
          ).strip)
        end
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
  url 'http://growl.cachefly.net/GrowlNotify-2.1.zip'
  sha1 '7880af1e9e6b1fff1174afe39eeeb59e25cf2674'

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
