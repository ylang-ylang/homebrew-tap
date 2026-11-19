class Rbwbio < Formula
  desc "rbwBio: Bitwarden CLI with opt-in face authorization"
  homepage "https://github.com/ylangs-fork/rbw"
  url "https://github.com/ylangs-fork/rbw.git", revision: "01da183c602cdc142815dbdeef003039bafb56fd"
  version "1.17.3"
  license all_of: ["MIT", "BSD-3-Clause"]
  head "https://github.com/ylangs-fork/rbw.git", branch: "main"

  bottle do
    root_url "https://github.com/ylang-ylang/homebrew-tap/releases/download/rbwbio-bottles-44518908027-1"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "ef60c594f83d341dd823d926ee5826dddeafb5a4f32ed901936b2e6d01b5870d"
    sha256 cellar: :any, x86_64_linux: "1dc5767209bad32f2d6f7dceafbf9e65824b3b8a6f851b35cd980fb619caabe9"
  end

  depends_on "rust" => :build
  depends_on "pinentry"
  conflicts_with "rbw", because: "both install rbw and rbw-agent binaries"

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

    on_intel do
      resource "face-runtime" do
        url "https://github.com/ylangs-fork/rbw/releases/download/face-runtime-44495312636-1/rbw-face-runtime-1.17.0-linux-x86_64-ubuntu22.04.tar.gz"
        sha256 "c93f0aa8022b79f401228764bd49a836d1ef3ce5f827166b2f6247a979850676"
      end
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
      if Hardware::CPU.intel?
        cp resource("face-runtime").cached_download, libexec/"face-runtime.tar.gz"
      end
    end
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"rbw", "gen-completions")
  end

  def caveats
    <<~EOS
      rbwBio keeps the rbw/rbw-agent commands and your existing config and vault.
      Run rbw login normally; face authorization is opt-in [y/N] (default No).
      Yes deploys the bundled runtime and opens a local live IR enrollment preview.
      The preview shows darkness and threshold; Cancel aborts without saving photos.
      Face recognition and notifications are verified before activation.
      Local face setup requires GNU/Linux x86_64, glibc >= 2.35 (Ubuntu 22.04/24.04
      or compatible Manjaro), an IR camera and desktop notifications; it may request sudo.
      Only opt-in deployment avoids downloads, package installation and compilation.
      Cold unlock still needs Master Password; unknown and sudo/login PAM policies stay unchanged.
      Use rbw setup --apply to enable later or repair. macOS is remote/requester only.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/rbw --version")
    assert_match "setup", shell_output("#{bin}/rbw --help")
    assert_match "--check", shell_output("#{bin}/rbw setup --help")
    system bin/"rbw", "gen-completions", "bash"
  end
end
