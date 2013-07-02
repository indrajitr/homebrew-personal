require 'formula'

class JavaDownloadStrategy < CurlDownloadStrategy
  def _fetch
    cookie = "gpw_e24=http://www.oracle.com/technetwork/java"
    curl @url, '-b', cookie, '-C', downloaded_size, '-o', @temporary_path
  end
end

class JavaSdk < Formula
  homepage 'http://www.oracle.com/technetwork/java/javase/index.html'
  url 'http://download.oracle.com/otn-pub/java/jdk/7u25-b15/jdk-7u25-macosx-x64.dmg', :using => JavaDownloadStrategy
  sha1 '302164484e6d4dde1f64a658c155facc1130a1de'
  version '1.7.0_25'

  keg_only "Java SDK is installed via system package installer."

  depends_on :macos => :lion

  BUNDLE_ID_PREFIX = "com.oracle.jdk7u25"

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

  def mount_dmg(mountpoint, &block)
    hdiutil_mount mountpoint, Dir['*.dmg'].first
    yield mountpoint if block_given?
  ensure
    ignore_interrupts{ hdiutil_unmount mountpoint } if mountpoint.exist?
  end

  def hdiutil_mount(mountpoint, dmgfile)
    args = ['/usr/bin/hdiutil', 'mount']
    args += ['-nobrowse', '-readonly', '-noidme']
    args << '-quiet' unless ARGV.verbose?
    args += ['-mountpoint', mountpoint, dmgfile]
    safe_system *args
  end

  def hdiutil_unmount(mountpoint)
    args = ['/usr/bin/hdiutil', 'unmount']
    args << '-quiet' unless ARGV.verbose?
    args << mountpoint
    safe_system *args
  end

  def installed_files(package)
    Dir.glob("/var/db/receipts/#{package.to_s}*.plist").map do |plist|
      prefix = "/#{`/usr/bin/defaults read #{plist} InstallPrefixPath`.chuzzle}"
      id = `/usr/bin/defaults read #{plist} PackageIdentifier`.chuzzle
     `/usr/bin/lsbom -f -l -s -pf /var/db/receipts/'#{id}'.bom`.chuzzle.map do |line|
        Pathname.new("#{prefix}/#{line}").cleanpath.to_s.chuzzle
      end
    end.flatten
  end

  def install
    (prefix+'README').write <<-EOS
      #{caveats}
      EOS

    (prefix+'files.txt').write <<-EOS.undent
      #{installed_files(BUNDLE_ID_PREFIX).join("\n      ")}
      EOS

    mount_dmg(@buildpath/name) do |mount_point|
      pkg_file = Dir["#{mount_point}/*.pkg"].first
      safe_system "sudo", "installer", "-pkg", pkg_file, "-target", target_device
    end
  end

  def caveats; <<-EOS.undent
    We agreed to the Oracle Binary Code License Agreement for you by downloading the SDK.
    If this is unacceptable you should uninstall.

    License information at:
    http://www.oracle.com/technetwork/java/javase/terms/license/index.html

    Java SDK is available in '.pkg' format and is installed via system
    package installer (installer -pkg). Thus `brew uninstall` will not
    remove it completely.

    To uninstall, consider manually deleting the files listed in
    #{prefix}/files.txt
    EOS
  end

  test do
    java_home = `/usr/libexec/java_home -v '#{version}'`.chuzzle
    system "#{java_home}/bin/java", "-version"
  end

end
