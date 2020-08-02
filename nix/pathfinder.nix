{ sources ? import ./sources.nix }:

let
  pkgs = import sources.nixpkgs {};
  cargo-c = import ./cargo-c.nix { inherit sources; };
in
pkgs.rustPlatform.buildRustPackage rec {
  pname = "pathfinder_c";
  version = "0.1.0";

  src = sources.pathfinder;

  cargoSha256 = "0bbpvp8kzm5ccvj13q1lb34n83jm3i0pi2yyhscw7wyvhwcvj44b";

  nativeBuildInputs = [ pkgs.pkg-config cargo-c ];
  buildInputs = with pkgs; [ xorg.libX11 freetype gtk3 ];

  buildAndTestSubdir = "c";

  postBuild = ''
    cargo cbuild --release --frozen --prefix=${placeholder "out"}
  '';

  postInstall = ''
    cargo cinstall --manifest-path c/Cargo.toml --release --frozen --prefix=${placeholder "out"}
    hfile=$(find $out -name pathfinder_c.h)
    sed -i "s/typedef SVGScene \*PFSVGSceneRef;/typedef struct SVGScene *PFSVGSceneRef;/" $hfile
  '';
}
