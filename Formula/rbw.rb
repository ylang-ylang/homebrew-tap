class Rbw < Formula
  desc "Unofficial Bitwarden CLI client (ylangs-fork build)"
  homepage "https://github.com/ylangs-fork/rbw"
  url "https://github.com/ylangs-fork/rbw.git", revision: "ea545ad28c30991de8a0f04fee99fcf3c4c97dc5"
  version "1.17.0"
  license all_of: ["MIT", "BSD-3-Clause"]
  head "https://github.com/ylangs-fork/rbw.git", branch: "main"

  bottle do
    root_url "https://github.com/ylang-ylang/homebrew-tap/releases/download/rbw-bottles-44502330551-1"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "1a1e934c9f707c242e0319b2c6a192f039cecd8fb0860a792fd649d077a920a2"
    sha256 cellar: :any, x86_64_linux: "de35eaed2a0f00e194b6490070a3c23899e23b638101000816a51f0b8d35af6d"
  end

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
      Run rbw login normally. Interactive login offers face authorization [y/N].
      No keeps ordinary rbw behavior. Yes deploys the precompiled face runtime,
      enrolls your face, verifies recognition and notifications, and activates it.
      The Linux x86_64 runtime supports Ubuntu 22.04/24.04 and may request sudo.
      Opt-in setup never runs apt/pip, network downloads, or a compiler.
      Each local authorization notifies the desktop while recognizing your face.
      sudo/login policies are unchanged; cold unlock still needs Master Password.
      Use rbw setup --apply only to enable later or repair enrollment.
      macOS supports remote/requester use, not local Howdy face authorization.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/rbw --version")
    assert_match "setup", shell_output("#{bin}/rbw --help")
    assert_match "--check", shell_output("#{bin}/rbw setup --help")
    system bin/"rbw", "gen-completions", "bash"
  end
end
