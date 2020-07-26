{ sources ? import ./sources.nix }:

let
  pkgs = import sources.nixpkgs {};
  naersk = pkgs.callPackage sources.naersk {};
  pname = sources.cargo-c.repo;
  version = sources.cargo-c.version;

  src = pkgs.stdenv.mkDerivation rec {
    name = "${pname}-source-${version}";

    src = sources.cargo-c;
    cargoLock = sources.cargo-c-lock;

    installPhase = ''
      mkdir -p $out
      cp -R ./* $out/
      cp ${cargoLock} $out/Cargo.lock

      # Remove the `default-run` property from `Cargo.toml
      # For whatever reason the property breaks naersk
      sed -i "s/^[^\n]*default-run[^\n]*//g" $out/Cargo.toml
    '';
  };
in
naersk.buildPackage {
  name = pname;
  inherit version;

  inherit src;
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.openssl ];
}
