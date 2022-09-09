{ nixosConfig, config, lib, ... }: with lib; let
  cfg = config.smp;
  pinning = cfg.pinning;
  vfiocfg = nixosConfig.hardware.vfio;
  vcpu = imap0 (i: processor: nameValuePair "vcpu${toString i}" {
    name = "vcpu";
    settings = {
      vcpunum = i;
      affinity = processor;
    };
  }) pinning.allocation;
in {
  options.smp = {
    pinning = {
      enable = mkEnableOption "VCPU pinning" // {
        default = true;
      };
      mode = mkOption {
        type = types.enum [ "vcpu" "cpuset" ];
        default = if vfiocfg.qemu.package.pname or null == "qemu-vfio" then "vcpu" else "cpuset";
      };
      threadOffset = mkOption {
        type = types.int;
        default = 0;
      };
      coreOffset = mkOption {
        type = types.int;
        default = 0;
      };
      isolate = mkEnableOption "cpuisol";
      allocation = mkOption {
        type = with types; listOf int;
        default = let
          alloc = genList (coreId:
            genList (threadId: {
              coreId = pinning.coreOffset + coreId;
              threadId = pinning.threadOffset + threadId;
            }) cfg.settings.threads
          ) cfg.settings.cores;
          findCore = { coreId, threadId }: findFirst (proc: proc.coreId == coreId && proc.threadId == threadId) null nixosConfig.hardware.cpu.info.processors;
        in map (alloc: (findCore alloc).processorId or (throw "could not find core=${toString alloc.coreId} thread=${toString alloc.threadId}")) (concatLists alloc);
      };
    };
  };
  config = mkIf pinning.enable {
    cli = mkIf (pinning.mode == "vcpu") (listToAttrs vcpu);
  };
}
