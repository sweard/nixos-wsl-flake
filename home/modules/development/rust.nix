{ pkgs, ... }:
let
  rustToolchain = pkgs.rust-bin.stable.latest.default.override {
    extensions = [
      "rust-src"
      "rustfmt"
      "clippy"
      "rust-analyzer"
    ];
    targets = [
      "aarch64-linux-android"
      "armv7-linux-androideabi"
      "i686-linux-android"
      "x86_64-linux-android"
    ];
  };
in
{
  home.packages = [
    rustToolchain
    pkgs.cargo-edit
    pkgs.cargo-watch
    pkgs.cargo-expand
    pkgs.sccache
  ];

  home.sessionVariables = {
    RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
    RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
  };
}
