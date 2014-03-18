require 'formula'

class JavaDownloadStrategy < CurlDownloadStrategy
  def _fetch
    cookie = "oraclelicense=accept-securebackup-cookie"
    curl @url, '-b', cookie, '-C', downloaded_size, '-o', @temporary_path
  end
end

class JavaDocs < Formula
  url 'http://download.oracle.com/otn-pub/java/jdk/8-b132/jdk-8-apidocs.zip', :using => JavaDownloadStrategy
  sha1 '81e496940727f0be09f76f1205ead5862f4cc955'
end

class UnlimitedJcePolicy < Formula
  url 'http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip', :using => JavaDownloadStrategy
  sha1 '7d25dcee3e6ef2c984d748a14614b37c18ce3507'
end

class JavaSdk < Formula
  homepage 'http://www.oracle.com/technetwork/java/javase/index.html'
  url 'http://download.oracle.com/otn-pub/java/jdk/8-b132/jdk-8-macosx-x64.dmg', :using => JavaDownloadStrategy
  sha1 'f4fe5a5f3e48cdeecd1d1ec9d380cf0c95ee3979'
  version '1.8.0'

  keg_only 'Java SDK is installed via system package installer.'

  depends_on :macos => :mountain_lion

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
  # - "/Library/Java/JavaVirtualMachines/jdk1.8.0.jdk/Contents/Home" go under "com.oracle.jdk8"
  # - "/Library/Internet Plug-Ins/JavaAppletPlugin.plugin" go under "com.oracle.jre"
  # - "/Library/PreferencePanes/JavaControlPanel.prefPane" go under "com.oracle.jre"
  def bundle_id_pattern(suffixes = [], prefix = 'com.oracle')
    # Pattern would be like: "com.oracle.(jdk8|jre)"
    return "#{prefix}.(#{suffixes.join('|')})"
  end

  def jdk_home_suffix
    # build.devel? ? 'jdk8' : 'jdk7u51'
    'jdk8'
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
    packages_with_bundle_id(bundle_id_pattern([jdk_home_suffix, 'jre'])).map do |pkg|
      prefix = read_receipt(pkg, 'InstallPrefixPath')
      files_with_bundle_id(read_receipt(pkg, 'PackageIdentifier')).map do |file|
        Pathname.new("#{target_device}/#{prefix}/#{file}").cleanpath
      end
    end.flatten
  end

  def jdk_installed_base
    pkg = packages_with_bundle_id(bundle_id_pattern([jdk_home_suffix])).first
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

  def post_install
    if build.with? 'docs'
      # Java SDK documentation linked from inside SDK home
      # See: http://www.oracle.com/technetwork/java/javase/javase7-install-docs-439822.html
      dest = Pathname.new("#{jdk_installed_base}/Contents/Home/docs")
      unless dest.symlink? or dest.directory?
        safe_system 'sudo', 'ln', '-s', doc, dest
      else
        puts "Skipping; already exists: #{dest}" if ARGV.verbose?
      end
    end

    if build.with? 'unlimited-jce'
      # JCE Unlimited Strength Jurisdiction Policy files replace the strong
      # policy files inside SDK's JRE home
      # See: #{prefix + 'jre/lib/security'}/README.txt
      dest = Pathname.new("#{jdk_installed_base}/Contents/Home/jre/lib/security/")
      ['US_export_policy.jar', 'local_policy.jar'].each do |jar|
        safe_system 'sudo', 'ln', '-sf', prefix + 'jre/lib/security/' + jar, dest
      end
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
    system "#{java_home}/bin/java", '-version'
  end
end
