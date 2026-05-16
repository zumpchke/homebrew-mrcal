class Libdogleg < Formula
  desc "Powell's dogleg nonlinear least squares with sparse Jacobians via CHOLMOD"
  homepage "https://github.com/dkogan/libdogleg"
  url "https://github.com/dkogan/libdogleg/archive/refs/tags/v0.18.tar.gz"
  sha256 "d97ef0c149463f84e9bd40c8852da444605a38bac432b5b2774de3dd15180bab"
  license "LGPL-3.0-or-later"

  depends_on "gcc"
  depends_on "suite-sparse"

  resource "mrbuild" do
    url "https://github.com/dkogan/mrbuild/archive/refs/tags/v1.16.tar.gz"
    sha256 "f2ae97ce0b6a2d5bfab132a27757c269cb378c22bc4b5e1e0e36380abc954433"
  end

  def install
    resource("mrbuild").stage { (buildpath/"mrbuild-1.16").install Dir["*"] }
    buildpath.install_symlink "mrbuild-1.16" => "mrbuild"

    gcc_major = Formula["gcc"].version.major.to_i
    ENV["CC"]  = Formula["gcc"].opt_bin/"gcc-#{gcc_major}"
    ENV["CXX"] = Formula["gcc"].opt_bin/"g++-#{gcc_major}"

    # suite-sparse is keg-only; mrbuild reads CFLAGS/LDFLAGS, not CPPFLAGS
    ENV.append "CFLAGS",  "-I#{Formula["suite-sparse"].opt_include}"
    ENV.append "LDFLAGS", "-L#{Formula["suite-sparse"].opt_lib}"

    system "make"

    include.install "dogleg.h"
    lib.install Dir["libdogleg.dylib*"]
  end

  test do
    (testpath/"test.c").write <<~C
      #include <dogleg.h>
      int main(void) { return 0; }
    C
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-ldogleg", "-o", "test"
  end
end
