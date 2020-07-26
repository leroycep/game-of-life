let
  sources = import ./nix/sources.nix;
  pathfinder_c = import ./nix/pathfinder.nix { inherit sources; };
  pkgs = import sources.nixpkgs {};
in
pkgs.mkShell {
  buildInputs = [
    pkgs.python38Packages.livereload
    pkgs.gdb
    pkgs.SDL2
    pkgs.pkg-config
    pathfinder_c
  ];
}
