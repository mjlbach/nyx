{ config, lib, ... }:

with lib;
let
  cfg = config.nyx.users.eden;
  # TODO: Determine platform linux/darwin and set homeDirectory to either
  # `/home/eden` or `/Users/eden`
in
{
  options.nyx.users.eden = {
    enable = mkEnableOption "Eden user information";
  };

  config = mkIf cfg.enable {
    nyx.user = {
      username = "eden";
      homeDirectory = "/home/eden";
      email = "edenofest@gmail.com";
      name = "James Simpson";
    };
  };
}

