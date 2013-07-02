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
    @version ||= begin
      # Ask Spotlight where GrowlHelperApp is
      path = MacOS.app_with_bundle_id(GROWL_HELPER_BUNDLE_ID)
      if not path.nil? and path.exist?
        # And detect version if found
        GrowlHelperAppVersion.new(`mdls -raw -name kMDItemVersion "#{path}" 2>/dev/null`.strip)
      end
    end

    @min_version <= @version
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

  keg_only "#{name} is installed via system package installer."

  depends_on :macos => :lion
  depends_on GrowlHelperAppRequirement.new

  BUNDLE_ID_PREFIX = "info.growl.growlnotify"

  def install
    (prefix+'README').write <<-EOS
      #{caveats}
      EOS

    (prefix+'files.txt').write <<-EOS.undent
      #{installed_files(BUNDLE_ID_PREFIX).join("\n      ")}
      EOS

    safe_system "sudo", "installer", "-pkg", "GrowlNotify.pkg", "-target", "/"
  end

  def caveats; <<-EOS.undent
    #{name} is available in '.pkg' format and is installed via system
    package installer (installer -pkg). Thus `brew uninstall` will not
    remove it completely.

    To uninstall, consider manually deleting the files listed in
    #{prefix}/files.txt
    EOS
  end

  test do
    system "growlnotify", "--version"
  end

  def installed_files(package)
    packages = `/usr/sbin/pkgutil --packages --volume #{target_device}`.select { |p| p =~ %r{#{BUNDLE_ID_PREFIX}} }
    packages.map do |pkg|
      prefix = `/usr/bin/defaults read /var/db/receipts/#{pkg.chuzzle}.plist InstallPrefixPath`.chuzzle
      id = `/usr/bin/defaults read /var/db/receipts/#{pkg.chuzzle}.plist PackageIdentifier`.chuzzle
     `pkgutil --files #{id}`.chuzzle.map do |file|
        Pathname.new("#{target_device}/#{prefix}/#{file}").cleanpath.to_s.chuzzle
      end
    end.flatten
  end

end
