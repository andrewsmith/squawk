{
  description = "Linter for PostgreSQL, focused on migrations";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
        overlay = (final: prev:
          let inherit (prev) lib;
          in
          {
            # Pin libpg_query to the latest 13-* release. Newer releases of
            # libpg_query use PostgreSQL > 13's parser, which yields a slightly
            # different AST than what Squawk currently supports, leading to
            # invalid-statement errors for valid statements.
            libpg_query13 = prev.libpg_query.overrideAttrs (_: rec {
              version = "13-2.2.0";
              src = final.fetchFromGitHub {
                owner = "pganalyze";
                repo = "libpg_query";
                rev = version;
                sha256 = "sha256-gEkcv/j8ySUYmM9lx1hRF/SmuQMYVHwZAIYOaCQWAFs=";
              };
            });

            squawk = final.rustPlatform.buildRustPackage {
              pname = "squawk";
              version = "0.19.0";

              cargoLock = {
                lockFile = ./Cargo.lock;
              };

              src = ./.;

              nativeBuildInputs = with final; [
                pkg-config
                rustPlatform.bindgenHook
              ];

              buildInputs = with final; [
                libiconv
                openssl
              ] ++ lib.optionals final.stdenv.isDarwin (with final.darwin.apple_sdk.frameworks; [
                CoreFoundation
                Security
              ]);

              LIBPG_QUERY_PATH = final.libpg_query13;

              meta = with lib; {
                description = "Linter for PostgreSQL, focused on migrations";
                homepage = "https://github.com/sbdchd/squawk";
                license = licenses.gpl3Only;
                platforms = platforms.all;
              };
            };
          });
      in
      {
        packages = {
          squawk = pkgs.squawk;
        };
        defaultPackage = self.packages.${system}.squawk;
        checks = self.packages;

        # for debugging
        inherit pkgs;

        devShell = pkgs.squawk.overrideAttrs (old: {
          RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;

          nativeBuildInputs = old.nativeBuildInputs ++ (with pkgs; [
            cargo-insta
            clippy
            rustfmt
          ]);
        });
      });
}
