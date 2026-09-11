{
  description = "app";

  inputs = {
    zig-toolchain.url = "github:mazunki/zig-toolchain";
  };

  outputs = { self, zig-toolchain, ... }:
    let
      inherit (zig-toolchain) forAllSystems;
      inherit (zig-toolchain.lib) pkgsFor;
      pname = "app";
    in {
      devShells = forAllSystems (system: {
        default = zig-toolchain.lib.mkZigShell { pkgs = pkgsFor system; };
      });

      packages = forAllSystems (system:
        let toolchain = zig-toolchain.packages.${system};
        in {
          default = zig-toolchain.lib.mkZigPackage {
            pkgs = pkgsFor system;
            inherit pname;
            inherit (toolchain) zig;
            src = ./.;
          };
        });
    };
}
