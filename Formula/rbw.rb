class Rbw < Formula
  desc "Unofficial Bitwarden CLI client (ylangs-fork build)"
  homepage "https://github.com/ylangs-fork/rbw"
  url "https://github.com/ylangs-fork/rbw.git", revision: "ff6329045560f89125645ef57f2808e83d775559"
  version "1.16.0"
  license all_of: ["MIT", "BSD-3-Clause"]
  head "https://github.com/ylangs-fork/rbw.git", branch: "main"

  depends_on "rust" => :build
  depends_on "pinentry"

  on_linux do
    depends_on "meson" => :build
    depends_on "ninja" => :build
    depends_on "pkgconf" => :build

    # Homebrew's linux-pam reads user-writable brew/etc. rbw validates a
    # root-controlled /etc/pam.d policy, so its PAM library must read that path.
    resource "linux-pam" do
      url "https://github.com/linux-pam/linux-pam/releases/download/v1.7.3/Linux-PAM-1.7.3.tar.xz"
      sha256 "2ce4765fd49df6693771ef2941f81e33d8ee14b94a81a5c7b369aa3b137b85a5"
    end
  end

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    if OS.linux?
      pam_libdir = libexec/"pam"
      resource("linux-pam").stage do
        system "meson", "setup", "pam-build", "--prefix=#{libexec}", "--libdir=pam",
               "--sysconfdir=/etc", "-Dsecuredir=/usr/lib/security", "-Dvendordir=",
               "-Di18n=disabled", "-Ddocs=disabled", "-Daudit=disabled", "-Deconf=disabled",
               "-Dlogind=disabled", "-Delogind=disabled", "-Dselinux=disabled",
               "-Dnis=disabled", "-Dpam_unix=disabled", "-Dpam_userdb=disabled",
               "-Dexamples=false"
        system "meson", "compile", "-C", "pam-build", "pam", "pam_misc"
        pam_libdir.install "pam-build/libpam/libpam.so.0.85.1"
        pam_libdir.install_symlink "libpam.so.0.85.1" => "libpam.so.0"
        pam_libdir.install_symlink "libpam.so.0" => "libpam.so"
        pam_libdir.install "pam-build/libpam_misc/libpam_misc.so.0.82.1"
        pam_libdir.install_symlink "libpam_misc.so.0.82.1" => "libpam_misc.so.0"
        pam_libdir.install_symlink "libpam_misc.so.0" => "libpam_misc.so"
        (pkgshare/"linux-pam").install "Copyright"
      end
      ENV.append "RUSTFLAGS", "-L native=#{pam_libdir} -C link-arg=-Wl,-rpath,#{pam_libdir}"
    end
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"rbw", "gen-completions")
  end

  def caveats
    <<~EOS
      Linux face authorization uses the system's native Howdy PAM module.
      Configure Howdy's IR camera and enroll your face, then run:
        rbw setup --apply
        rbw setup --check
      Setup only installs rbw's dedicated PAM policy; it does not change sudo/login.
      Howdy, camera drivers, and face models are not included in this formula.
      macOS supports remote/requester use, not Howdy face authorization.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/rbw --version")
    assert_match "setup", shell_output("#{bin}/rbw --help")
    assert_match "--check", shell_output("#{bin}/rbw setup --help")
    system bin/"rbw", "gen-completions", "bash"
  end
end
