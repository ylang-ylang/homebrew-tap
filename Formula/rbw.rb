class Rbw < Formula
  desc "Unofficial Bitwarden CLI client (ylangs-fork build)"
  homepage "https://github.com/ylangs-fork/rbw"
  url "https://github.com/ylangs-fork/rbw.git", revision: "77464d414a9e41165d5b15f049bee1f0c0f2a982"
  version "1.15.0"
  license "MIT"
  head "https://github.com/ylangs-fork/rbw.git", branch: "main"

  bottle do
    root_url "https://github.com/ylang-ylang/homebrew-tap/releases/download/rbw-bottles-44272689759-1"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "b942df9195b0fc920abe97b7b92fb3135f580ea037ff864538356118a874190d"
    sha256 cellar: :any,                 x86_64_linux:  "d37fc90071f7cefc6ac237d65ece38f9cfb6814d71396f07d6c590102c109f50"
  end

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
