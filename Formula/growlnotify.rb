require 'formula'

class GrowlHelperAppRequirement < Requirement

  GROWL_HELPER_BUNDLE_ID = "com.Growl.GrowlHelperApp"

  fatal true

  def initialize(version = "2.1", tags = [])
    # Extract the version if given. Default to GrowlHelperApp 2.x
    @version = Version.new(version) if /(\d+\.)*\d+/ === version.to_s
    super tags
  end

  satisfy :build_env => false do
    helper_version ||= detect_version
    @version <= helper_version unless helper_version.nil?
  end

  # This technique is mostly taken from 'xcode.rb' in Homebrew library.
  def detect_version
    if (path = bundle_path) && path.exist? && (version = version_from_mdls(path))
      Version.new(version)
    else
      Version.new(version_from_pkgutil)
    end
  end

  def bundle_path
    MacOS.app_with_bundle_id(GROWL_HELPER_BUNDLE_ID)
  end

  # Ask Spotlight where Growl is. This is our best option even
  # if the user installed Growl in a non-conventional location.
  # See: http://superuser.com/questions/390757
  def version_from_mdls(path)
    version = Utils.popen_read(
      "/usr/bin/mdls", "-raw", "-nullMarker", "", "-name", "kMDItemVersion", path.to_s
    ).strip
    version unless version.empty?
  end

  # Growl Helper *does* have a pkg-info entry, so if we can't get it
  # from mdls, we can try pkgutil. This is very slow.
  def version_from_pkgutil
    version = MacOS.pkgutil_info(GROWL_HELPER_BUNDLE_ID)[/version: (.+)$/, 1]
    version unless version.empty?
  end

  def message; <<-EOS.undent
    Growl Helper App #{@version} or newer is required.
    Install it from the App Store at:
      https://itunes.apple.com/app/growl/id467939042?mt=12
    EOS
  end
end

class Growlnotify < Formula
  desc "Send Growl Notifications from the command-line"
  homepage "http://growl.info/downloads#generaldownloads"
  url "http://growl.cachefly.net/GrowlNotify-2.1.zip"
  sha256 "eec601488b19c9e9b9cb7f0081638436518bce782d079f6e43ddc195727c04ca"

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
