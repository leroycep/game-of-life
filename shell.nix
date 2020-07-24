let
  pkgs = import <nixpkgs> {};
in
pkgs.mkShell {
  buildInputs = [
    pkgs.python38Packages.livereload
    pkgs.SDL2
    pkgs.freetype
  ];
}
