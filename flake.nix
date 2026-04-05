{
  # description = "description";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
      name = "todo-ui";
      version = "v0.1.0";
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.buildNpmPackage {
            pname = name;
            version = version;
            src = ./.;

            npmDepsHash = "sha256-cuJI80donvM/l9DNeq+/+x52GVSFtNthF5izjqFOCQ4=";

            NG_CLI_ANALYTICS = "false";

            npmBuildScript = "build";
            installPhase = ''
              mkdir -p $out/share/www

              cp -r dist/${name}/browser/* $out/share/www/

              mkdir -p $out/bin
              cat <<EOF > $out/bin/${name}
              #!/bin/sh
              echo "Starting server at http://localhost:8080"
              # We serve the flattened www directory
              ${pkgs.python3}/bin/python3 -m http.server 8080 --directory $out/share/www
              EOF
              chmod +x $out/bin/${name}
            '';
          };
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          devScript = pkgs.writeShellApplication {
            name = "run-dev";
            runtimeInputs = [
              pkgs.nodejs_20
            ];
            text = ''
              # npm start runs the local ng serve from package.json
              npm start
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/${name}";
          };
          dev = {
            type = "app";
            program = "${devScript}/bin/run-dev";
            meta = {
              description = "live-reloading for development";
            };
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nodejs_20
              pkg-config
            ];

            shellHook = ''
              if [ ! -f angular.json ]; then
                # Create Angular Project on first Enter
                npx -p @angular/cli ng new ${name} --directory ./
              fi
            '';
          };
        }
      );
    };
}
