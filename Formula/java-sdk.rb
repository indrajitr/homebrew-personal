require 'formula'

class JavaDownloadStrategy < CurlDownloadStrategy
  def _curl_opts
    super << "-b" << "oraclelicense=accept-securebackup-cookie"
  end
end

class JavaSdk < Formula
  desc "Java SE 8 Development Kit"
  homepage "http://www.oracle.com/technetwork/java/javase/index.html"
  url "http://download.oracle.com/otn-pub/java/jdk/8u60-b27/jdk-8u60-macosx-x64.dmg", :using => JavaDownloadStrategy
  sha256 "554f4fef08a5ea5b5b6e90cacb62a7a390d94d96c27fa2a5d6b44fc73e45465e"
  version "1.8.0_60-b27"

  resource 'docs' do
    url "http://download.oracle.com/otn-pub/java/jdk/8u60-b27/jdk-8u60-docs-all.zip", :using => JavaDownloadStrategy
    sha256 "cbeffb41253da58f8924423f22a9bd53802633925664d68c46e6bfffd506a33d"
  end

  resource 'unlimited-jce' do
    url "http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip", :using => JavaDownloadStrategy
    sha256 "f3020a3922efd6626c2fff45695d527f34a8020e938a49292561f18ad1320b59"
  end

  keg_only "Java SDK is installed via system package installer."

  depends_on :arch => :x86_64
  depends_on :macos => :mountain_lion

  option "with-docs", "Also install SDK documentation"
  option "with-unlimited-jce", "Also install JCE Unlimited Strength Jurisdiction Policy Files"

  def options
    [["--target=<target_device>", "Install on a different volume, defaults to '/'"]]
  end

  def target_device
    # check arguments for a different target device
    ARGV.each do |a|
      return a.sub('--target=', '') if a.index('--target')
    end
    '/'
  end

  # java is installed under multiple bundle ids for example,
  # - "/Library/Java/JavaVirtualMachines/jdk1.8.0_60.jdk/Contents/Home" go under "com.oracle.jdk8u60"
  # - "/Library/Internet Plug-Ins/JavaAppletPlugin.plugin" go under "com.oracle.jre"
  # - "/Library/PreferencePanes/JavaControlPanel.prefPane" go under "com.oracle.jre"
  def bundle_id_pattern(suffixes = [], prefix = 'com.oracle')
    # Pattern would be like: "com.oracle.(jdk8u60|jre)"
    "#{prefix}.(#{suffixes.join('|')})"
  end

  def jdk_home_suffix; "jdk8u60" end

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

  def packages_with_bundle_id(id_prefix)
    (@packages ||= {}).fetch(id_prefix.to_s) do
      @packages[id_prefix.to_s] =
        `/usr/sbin/pkgutil --packages --volume #{target_device}`.split("\n").select { |p| p =~ %r{#{id_prefix}} }
    end
  end

  def files_with_bundle_id(id)
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

    doc.install resource('docs') if build.with? 'docs'
    (prefix + 'jce-policy').install resource('unlimited-jce') if build.with? 'unlimited-jce'
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
      # See: #{prefix + 'jce-policy'}/README.txt
      dest = Pathname.new("#{jdk_installed_base}/Contents/Home/jre/lib/security/")
      ['US_export_policy.jar', 'local_policy.jar'].each do |jar|
        safe_system 'sudo', 'cp', prefix + 'jce-policy/' + jar, dest
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
