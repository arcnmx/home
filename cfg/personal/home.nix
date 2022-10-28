{ base16, meta, tf, nixosConfig, options, config, pkgs, lib, ... } @ args: with lib; let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  mplay = pkgs.writeShellScriptBin "mplay" ''
    COUNT=$#
    mpc add "$@" &&
      mpc play $(($(mpc playlist | wc -l) - COUNT + 1))
  '';
  cfg = config.home.profileSettings.personal;
in {
  imports = [
    ./email.nix
    ../vim/personal.nix
    ../weechat
  ];
  options = {
    home.profileSettings.personal = {
      primaryHost = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      isPrimary = mkOption {
        type = types.bool;
        default = config.home.hostName == cfg.primaryHost;
      };
    };
  };

  config = {
    home.file = {
      ".electrum".source = mkOutOfStoreSymlink "${config.xdg.configHome}/electrum/";
    };
    home.sessionVariables = {
      SYSTEMD_PAGERSECURE = "1";
    };
    home.packages = with pkgs; [
      git-remote-gcrypt git-revise git-annex git-annex-remote-b2
      gnupg
      pass-arc
      bitwarden-cli
      playerctl
      awscli2
      physlock
      travis
      radare2
      electrum-cli
      jq yq
      mplay
      pinentry.curses
      #TODO: benc bsync snar-snapper
    ];
    home.profileSettings.personal = {
      primaryHost = "shanghai";
    };
    home.shell = {
      deprecationAliases = {
        ncpamixer = "pulsemixer";
      };
      functions = {
        mradio = ''
          mplay http://shanghai:32101
        '';
        unrar = ''
          nix shell --impure nixpkgs#unrar -c unrar "$@"
        '';
        direnv-init = ''
          printf '%s\n%s' \
            "export CI_PLATFORM=impure" \
            "use ${if config.services.lorri.useNix || !config.services.lorri.enable then "\${1-nix}" else "lorri"}" \
            > .envrc
        '' + optionalString config.services.lorri.enable ''
          for nixfile in $PWD/shell.nix; do # default.nix?
            if [[ -e $nixfile ]]; then
              ${config.services.lorri.package}/bin/lorri ping_ $nixfile
              break
            fi
          done
        '' + ''
          direnv allow
        '';
        iclip = ''
          local ICLIP_DIR=/run/iclip
          local ICLIP_FILE=$ICLIP_DIR/_clip.txt ICLIP_TMP
          if [[ $1 = -o ]]; then
              cat "$ICLIP_DIR/$(ls -rt "$ICLIP_DIR" | tail -n 1)"
          elif [[ $1 = -d ]]; then
              rm "$ICLIP_DIR/"*
          else
              ICLIP_TMP=$(mktemp --tmpdir iclip.XXXXXXXXXX)
              cat > "$ICLIP_TMP" && mv "$ICLIP_TMP" "$ICLIP_FILE"
          fi
        '';
      } // optionalAttrs config.services.lorri.enable {
        lorri-status = ''
          ${config.systemd.package}/bin/systemctl --user status lorri.service
        '';
        lorri-log = ''
          ${config.systemd.package}/bin/journalctl --user -fu lorri.service
        '';
      };
    };
    #services.lorri.enable = true;
    services.gpg-agent = {
      enable = true;
      enableExtraSocket = true;
      enableScDaemon = false;
      enableSshSupport = true;
      pinentryFlavor = mkDefault null;
      extraConfig = mkMerge [
        "auto-expand-secmem 0x30000" # otherwise "gpg: public key decryption failed: Cannot allocate memory"
        "pinentry-timeout 30"
        "allow-loopback-pinentry"
        "no-allow-external-cache"
      ];
      #defaultCacheTtl = 31536000; maxCacheTtl = 31536000; defaultCacheTtlSsh = 31536000; maxCacheTtlSsh = 31536000; # doing a bad remove me later thanks
    };
    services.${if options ? services.idle then "idle" else null}.enable =
      mkIf config.xsession.enable (mkDefault true);
    programs.zsh = {
      dirHashes = {
        gen = "${config.xdg.userDirs.documents}/gensokyo";
        fork = "${config.xdg.userDirs.documents}/fork";
        nix = "${config.xdg.userDirs.documents}/nix";
      };
    };
    programs.git = {
      package = pkgs.git;
      extraConfig = {
        gcrypt = {
          require-explicit-force-push = false;
        };
      };
    };
    programs.gh = {
      enable = !config.home.minimalSystem;
      settings.git_protocol = "ssh";
    };
    programs.bitw.enable = mkDefault (!config.home.minimalSystem);
    programs.buku = {
      enable = !config.home.minimalSystem;
      bookmarks = {
        howoldis = {
          title = "NixOS Channel Freshness";
          url = "https://status.nixos.org/";
          tags = [ "nix" "nixos" "channels" ];
        };
        nixexprs-ci = {
          title = "nixexprs CI";
          url = "https://github.com/arcnmx/nixexprs/actions";
          tags = [ "arc" "ci" "nix" "nixexprs" "actions" ];
        };
      };
    };
    programs.ncpamixer = {
      enable = false;
      keybinds = {
        "48" = "set_volume_100"; # 0
        "96" = "set_volume_0"; # `
        "74" = "tab_next"; # J
        "75" = "tab_prev"; # K
      };
    };
    programs.pulsemixer = {
      enable = nixosConfig.hardware.pulseaudio.enable or pkgs.hostPlatform.isLinux || nixosConfig.services.pipewire.enable or false;
      configContent.keys = {
        next-mode = "J";
        prev-mode = "K";
        mute = "m, `";
      };
    };
    programs.filebin = {
      enable = !config.home.minimalSystem;
      extraConfig = ''
        AWS_ACCESS_KEY_ID=$(bitw get tokens/aws-filebin -f aws_access_key_id)
        AWS_SECRET_ACCESS_KEY=$(bitw get tokens/aws-filebin -f aws_secret_access_key)
        FILEBIN_S3_BUCKET=$(bitw get tokens/aws-filebin -f s3_bucket_name)
        FILEBIN_BOXCAR_KEY=$(bitw get tokens/boxcar-filebin -f notes)
      '';
    };
    programs.kakoune = {
      config.hooks = [
        {
          name = "WinSetOption";
          option = "filetype=(rust|yaml|nix|markdown)";
          commands = "lsp-enable-window";
        }
      ];
      pluginsExt = with pkgs.kakPlugins; [
        kak-lsp
        kak-tree
      ];
    };
    programs.rustfmt = {
      package = pkgs.rustfmt-nightly;
    };

    xdg.configFile = {
      "electrum/.keep".text = "";
      "kak-lsp/kak-lsp.toml".source = pkgs.substituteAll {
        inherit (pkgs) efm-langserver rnix-lsp;
        #inherit (pkgs.nodePackages) vscode-html-languageserver-bin vscode-css-languageserver-bin vscode-json-languageserver;
        src = ./files/kak-lsp.toml;
      };
      "cargo/config" = mkIf tf.state.enable {
        source = mkOutOfStoreSymlink config.secrets.files.cargo-config.path;
      };
    };
    secrets.files = {
      cargo-config.text = ''
        [registry]
        token = "${tf.variables.CRATES_TOKEN_ARC.ref}"
      '';
    };

    programs.ssh.strictHostKeyChecking = "accept-new";
    services.sshd.authorizedKeys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCik1rxKNKDBcIQrFrleGXlz/SwJXmC7TjAHqO3QXe0sIR4/egYhQlKSWLWiV/HviMJ0RNuBMNG6yfNpItNAvkKT9nExxyRFC4PAkYf4mBk6x4Re9hAE9FM9KAe7cFBx/+xD6VxJYGEoKyWejuCE16Tn48G7TEQyxr0bJwO9jL+LKAS+/Za3mx2kyKZNmn7b4Roa9uWeJDFpmzqsOmvxiLpF5sQ4EyKaiifyVUKaPGdoonVKXQMmnzyBP/e553raLYV13bGzPKBq8UnRHKmVbNSotIrGZ/X/PBT/Y8jRRZhba2hhai8ofGtkIhzdPWdTs30qlBrbRa2nEeVEVC6mKzv+gMtb0kiNOxb4ceKUpAntMUr2aCjsF1OTkROOqbLg8nTHAIM9JHFDNZmzDGa7kjtn4c8V4X/beydTAWNDClLG9CWwjG+X+ZpGsuOFX/ke62pcj44tK+qm1XckdX1HyCXrG7R4AeOyqZ8uXla5QoUgsK8qEa1ZFbRgQQtC595DvsQosfnJXrKuDurEeBfl/Ew4ugIHQvHioeAUAxG80WYJHyCfdh1V0a5fB19LEiWDZyy7uUqsuJYG8LWTrpJaM/PTbUaFI4No5vhSCKjmbFalJRhyGMbrhr+x7jnW1JRXS6lkvoDbJlUPLBRg63t6cZeXWCdMcXo1Me9Octc2XSSLQ== arc@shanghai"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDMBsg/h3ITy/2u1IpTpazEMU+hKaThjC7wDPQzIKvicw6Hf+O7M8uw6DSFXAXhjygLvonhKhlVt6qKzrSJrKZDPewT/hkgFU2Zvj8JwWzSJKg9SYR6v0L1GYF2gB1K/QKNrXDxT0yoov/NDlN1lkVyYM9IMDRXVXx5SkojffMv9YC6NBZfOeaEmkKY3VCg5tePUF5limp9ipBzqjjIitDmNWBV/ID2paV/SIasGMfUFtipO5r8Bg4Wgv5sJPCWE82iYhZdJJkfHr8vn7M7ITMCQ00daSZlu2McCFkff+ZMe/wejX5xxyOXx9xI2yomzN77rMSl45pBp8MnHIigJ0zRiMSHfjpDkwVQiaMdMG6bti7wRbEw6fKWLHcRqnZ3sWMxNLNnSO8WGdAXt6WIPJ2IBSSp/XmDxFu30Ag9soOqprqTLVXzxfdj0vLAPdMRQI2LuVL4wNfXS7FJxiOs9oQFvxdaxmqxRyry3fafl2Z5epdgw3dgu2G7fkvy9NEuoFoZfYyNVFkIsJ/AktyFvr9ajimN1xfuyIlXXmZJRqoMQ8gZY+Qcguug2g9IhjRyVOglQiQp1V/JETtpScOFuD2xpwLTZ2Y3Ij21+XOnrI88Izcox+QAQvAyHGfoPwG5Zwj2A0gT+c9xaAEH+nQOyZ6xp5uY+7cpN/F0Z0XDRBWnvw== arc@shanghai-tan"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvdvIjXlLTpG2QlMi1kGYfgPXCDIsDM1Ldn4uPO3kz+uEJEgSrqVuKD71VAEZfN93HVZ4BoBTrjXC+jc0nSZjUgccCdo9aSZ87JbdocivNxwXxy9c/0B4+WU9+NB16VpVX+t43xgJxKfV9TW2QOLE0h0MMJizCsyX9rFMF4EOIR3TYe8Mm8x2L6axP4SZ7X+2aEyWg7VcEjzheKWvu+C4/B0c4D1/WtHcTrfy4/2urjvgYEXw5UVz7KOIXR0jIk2cvePOrjppDy8TjJxcm3zkFT4ZYuACWDiqfVZKuqAFI89kZ6fufbbHR1RilfHiehnPyzGj7KgPtwSgbxPJ9yvwX iphonese-prompt"
    ];
  };
}
