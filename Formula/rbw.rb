class Rbw < Formula
  desc "Unofficial Bitwarden CLI client (ylangs-fork build)"
  homepage "https://github.com/ylangs-fork/rbw"
  url "https://github.com/ylangs-fork/rbw.git", revision: "77464d414a9e41165d5b15f049bee1f0c0f2a982"
  version "1.15.0"
  license "MIT"
  head "https://github.com/ylangs-fork/rbw.git", branch: "main"

  depends_on "rust" => :build
  depends_on "pinentry"

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"rbw", "gen-completions")
  end
end
