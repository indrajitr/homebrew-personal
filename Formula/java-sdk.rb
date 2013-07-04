require 'formula'

class JavaDownloadStrategy < CurlDownloadStrategy
  def _fetch
    cookie = "gpw_e24=http://www.oracle.com/technetwork/java"
    curl @url, '-b', cookie, '-C', downloaded_size, '-o', @temporary_path
  end
end

class JavaDocs < Formula
  url 'http://download.oracle.com/otn-pub/java/jdk/7u25-b15/jdk-7u25-apidocs.zip', :using => JavaDownloadStrategy
  sha1 '60b9945344cfbe0867d4c5be234d9795745ec727'
end

class UnlimitedJcePolicy < Formula
  url 'http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip', :using => JavaDownloadStrategy
  sha1 '7d3c9ee89536b82cd21c680088b1bced16017253'
end

class JavaSdk < Formula
  homepage 'http://www.oracle.com/technetwork/java/javase/index.html'
  url 'http://download.oracle.com/otn-pub/java/jdk/7u25-b15/jdk-7u25-macosx-x64.dmg', :using => JavaDownloadStrategy
  sha1 '302164484e6d4dde1f64a658c155facc1130a1de'
  version '1.7.0_25'

  keg_only 'Java SDK is installed via system package installer.'

  depends_on :macos => :lion

  option 'with-docs', 'Also install SDK documentation'
  option 'with-unlimited-jce', 'Also install JCE Unlimited Strength Jurisdiction Policy Files'

  def options
    [['--target=<target_device>', "Install on a different volume, defaults to '/'"]]
  end

  def target_device
    # check arguments for a different target device
    ARGV.each do |a|
      return a.sub('--target=', '') if a.index('--target')
    end
    '/'
  end

  # java is installed under multiple bundle ids for example,
  # - "/Library/Java/JavaVirtualMachines/jdk1.7.0_25/Contents/Home" go under "com.oracle.jdk7u25"
  # - "/Library/Internet Plug-Ins/JavaAppletPlugin.plugin" go under "com.oracle.jre"
  # - "/Library/PreferencePanes/JavaControlPanel.prefPane" go under "com.oracle.jre"
  def bundle_id_pattern(suffixes = [], prefix = 'com.oracle')
    # Pattern would be like: "com.oracle.(jdk7u25|jre)"
    return "#{prefix}.(#{suffixes.join('|')})"
  end

  # mount dmg, do everything in the block and ensure dmg is unmounted
  def mount_dmg(mountpoint, &block)
    hdiutil_mount mountpoint, Dir['*.dmg'].first
    yield mountpoint if block_given?
  ensure
    ignore_interrupts { hdiutil_unmount mountpoint } if mountpoint.exist?
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

  def installed_files
    packages_with_bundle_id(bundle_id_pattern(['jdk7u25', 'jre'])).map do |pkg|
      prefix = read_receipt(pkg, 'InstallPrefixPath')
      files_with_bundle_id(read_receipt(pkg, 'PackageIdentifier')).map do |file|
        Pathname.new("#{target_device}/#{prefix}/#{file}").cleanpath
      end
    end.flatten
  end

  def jdk_installed_base
    pkg = packages_with_bundle_id(bundle_id_pattern(['jdk7u25'])).first
    prefix = read_receipt(pkg, 'InstallPrefixPath') unless pkg.nil? or pkg.empty?
    Pathname.new("#{target_device}/#{prefix}").cleanpath
  end

  def packages_with_bundle_id id_prefix
    (@packages ||= {}).fetch(id_prefix.to_s) do
      @packages[id_prefix.to_s] =
        `/usr/sbin/pkgutil --packages --volume #{target_device}`.split("\n").select { |p| p =~ %r{#{id_prefix}} }
    end
  end

  def files_with_bundle_id id
    (@files ||= {}).fetch(id.to_s) do
      @files[id.to_s] = `/usr/sbin/pkgutil --files #{id}`.split("\n")
    end
  end

  def read_receipt(pkg, key)
    `/usr/bin/defaults read /var/db/receipts/#{pkg}.plist #{key}`.chomp
  end

  def install
    (prefix+'README').write <<-EOS
      #{caveats}
      EOS

    (prefix+'files.txt').write <<-EOS.undent
      #{installed_files.join("\n      ")}
      EOS

    mount_dmg(@buildpath/name) do |mount_point|
      pkg_file = Dir["#{mount_point}/*.pkg"].first
      safe_system 'sudo', 'installer', '-pkg', pkg_file, '-target', target_device
    end

    JavaDocs.new.brew { doc.install Dir['*'] } if build.with? 'docs'
    UnlimitedJcePolicy.new.brew { (prefix + 'jre/lib/security').install Dir['*'] } if build.with? 'unlimited-jce'
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

    If Java SDK documentation is installed (via '--with-docs'), it can
    be linked from inside SDK home:
    sudo ln -s #{doc} \\
          #{if File.directory?(jdk_installed_base)
              jdk_installed_base.to_s + '/Contents/Home/docs'
            else
              '${JAVA_HOME}/docs'
            end}

    For more, see: http://www.oracle.com/technetwork/java/javase/javase7-install-docs-439822.html

    If JCE Unlimited Strength Jurisdiction Policy Files is installed
    (via '--with-unlimited-jce'), the unlimited strength policy files
    can replace the strong policy files (optionally keeping a backup)
    inside SDK's JRE home:
    sudo ln -sf #{prefix + 'jre/lib/security'}/{US_export,local}_policy.jar \\
          #{if File.directory?(jdk_installed_base)
              jdk_installed_base.to_s + '/Contents/Home/jre/lib/security/'
            else
              '${JAVA_HOME}/jre/lib/security/'
            end}

    For more, see: #{prefix + 'jre/lib/security'}/README.txt
    EOS
  end

  test do
    java_home = `/usr/libexec/java_home -v '#{version}'`.chuzzle
    system "#{java_home}/bin/java", '-version'
  end
end
