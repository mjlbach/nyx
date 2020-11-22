{ config, lib, ... }:

with lib;
let
  cfg = config.nyx.user;
in
{
  imports = [
    ./eden.nix
  ];

  options.nyx.user = {
    username = mkOption {
      type = types.str;
      defaultText = literalExample ''
        "$USER"   for state version < 20.09,
        undefined for state version ≥ 20.09
      '';
      example = "jane.doe";
      description = "The user's username.";
    };

    homeDirectory = mkOption {
      type = types.path;
      defaultText = literalExample ''
        "$HOME"   for state version < 20.09,
        undefined for state version ≥ 20.09
      '';
      apply = toString;
      example = "/home/jane.doe";
      description = "The user's home directory. Must be an absolute path.";
    };

    name = mkOption {
      type = types.str;
      default = "";
      example = "Jane Doe";
      description = "The users full name";
    };

    email = mkOption {
      type = types.str;
      default = "";
      example = "your@email.here";
      description = "The users email";
    };
  };

  config = {
    nyx.user = {
      username = (mkDefault (builtins.getEnv "USER"));
      homeDirectory = (mkDefault (builtins.getEnv "HOME"));
    };
  };
}
