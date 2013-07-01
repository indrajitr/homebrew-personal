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

  depends_on :macos => :lion
  depends_on GrowlHelperAppRequirement.new

  def install
    (prefix+'README').write <<-EOS.undent
      #{name} is available in '.pkg' format and is installed via package
      installer (installer -pkg). Thus `brew uninstall` will not remove it
      completely.

      To uninstall, consider manually deleting the following files:
      #{installed_files("info.growl.growlnotify").join("\n")}
      EOS

    system "sudo", "installer", "-pkg", 'GrowlNotify.pkg', "-target", "/"
  end

  def caveats; <<-EOS.undent
    #{name} is available in '.pkg' format and is installed via package
    installer (installer -pkg). Thus `brew uninstall` will not remove it
    completely.

    To uninstall, consider manually deleting the files listed in:
    #{prefix}/README
    EOS
  end

  test do
    system "growlnotify", "--version"
  end

  def installed_files(package)
    # TODO: Simplify by using map and flatten
    @files = []
    Dir.glob("/var/db/receipts/#{package.to_s}.*.plist").each do |plist|
      @prefix = "/#{`/usr/bin/defaults read #{plist} InstallPrefixPath`.chomp}"
      @id = `/usr/bin/defaults read #{plist} PackageIdentifier`.chomp
      `/usr/bin/lsbom -f -l -s -pf /var/db/receipts/'#{@id}'.bom`.chomp.each_line do |line|
        @files << Pathname.new("#{@prefix}/#{line}").cleanpath
      end
    end
    @files
  end

end
