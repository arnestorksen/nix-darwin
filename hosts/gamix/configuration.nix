# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  # /boot is a 96M EFI partition (no room to grow it - the disk is fully
  # partitioned with a Windows dual-boot install alongside it), and each
  # generation's kernel+initrd is ~27M. 3 generations left only ~17M free,
  # which a single kernel bump was enough to exhaust. 2 keeps one fallback
  # generation while leaving real headroom.
  boot.loader.systemd-boot.configurationLimit = 2;
  boot.loader.efi.canTouchEfiVariables = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.settings.auto-optimise-store = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # QEMU userspace emulation for aarch64, so aarch64-linux derivations
  # (e.g. Raspberry Pi 3 SD images) can be built on this x86_64 host.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Games library, on its own ext4 partition (nvme0n1p4).
  fileSystems."/home/arne/Games" = {
    device = "/dev/disk/by-uuid/c8a9b8f2-74f1-42b9-88b0-86853c3c6544";
    fsType = "ext4";
  };

  # Swapfile for hibernation. Root only has ~13G free, so this lives on the
  # Games partition instead (744G free there); no dedicated swap partition
  # since the disk has no unpartitioned space to carve one out of.
  # 34G covers the ~32G (30GiB) of RAM with headroom for the resume image.
  swapDevices = [
    { device = "/home/arne/Games/swapfile"; size = 34 * 1024; }
  ];

  # Hibernation resume: the kernel reads the swap header directly off the
  # block device at a byte offset (resume_offset), bypassing the filesystem,
  # since the swapfile isn't its own partition. resume_offset is computed
  # after the swapfile exists on disk (see README/commit for the command)
  # and must be recomputed if the swapfile is ever recreated or moved.
  boot.resumeDevice = "/dev/disk/by-uuid/c8a9b8f2-74f1-42b9-88b0-86853c3c6544";
  # Offset of the swapfile's first extent (in 4K blocks), from:
  #   sudo filefrag -v /home/arne/Games/swapfile | head -5
  # Must be recomputed with the same command if the swapfile is ever
  # recreated (e.g. resized) — a stale offset makes resume silently fail.
  boot.kernelParams = [ "resume_offset=150892544" ];

  # systemd-logind runs with ProtectHome=yes, which hides all of /home
  # (including our swapfile) from it. It needs to read the file directly to
  # compute the on-disk offset when hibernate is triggered (e.g. from the
  # KDE session). BindReadOnlyPaths doesn't reliably punch through
  # ProtectHome for a path that crosses onto a separate mounted filesystem
  # like /home/arne/Games, so just disable the protection for this unit.
  systemd.services.systemd-logind.serviceConfig.ProtectHome =
    lib.mkForce false;

  networking.hostName = "gamix"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Oslo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "nb_NO.UTF-8";
    LC_IDENTIFICATION = "nb_NO.UTF-8";
    LC_MEASUREMENT = "nb_NO.UTF-8";
    LC_MONETARY = "nb_NO.UTF-8";
    LC_NAME = "nb_NO.UTF-8";
    LC_NUMERIC = "nb_NO.UTF-8";
    LC_PAPER = "nb_NO.UTF-8";
    LC_TELEPHONE = "nb_NO.UTF-8";
    LC_TIME = "nb_NO.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "no";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "no";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Enable flakes
  #nix.settings.experimental-features = "nix-command flakes";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."arne" = {
    isNormalUser = true;
    description = "Arne Mellesmo Størksen";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };

  # Registers zsh in /etc/shells so it's valid as a login shell above;
  # actual dotfile/config management is done by home-manager (home/common.nix).
  programs.zsh.enable = true;

  # 32-bit support is needed for Steam/Proton; amdgpu (open-source) covers
  # both the Raphael iGPU and the RX 6800-series discrete card here.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Gaming
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  programs.gamemode.enable = true;

  # GPU fan curve control (AMD RX 6800-series). Polkit rule shipped by the
  # package grants access to the "wheel" group, which arne is already in.
  programs.corectrl.enable = true;

  # 1Password. These modules (rather than plain home-manager packages) set up
  # the polkit rules and setuid wrapper needed for browser native-messaging
  # and system-auth unlock.
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "arne" ];
  };

  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    vivaldi
    neovim

    # Gaming
    lutris
    heroic # Epic Games Store + GOG, native launcher (uses legendary/gogdl)
    mangohud
    protonup-qt
    discord
    prismlauncher
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # Minecraft "Open to LAN" discovery: the host broadcasts a multicast
  # announcement on UDP 4445 that populates the client's LAN-world list.
  networking.firewall.allowedUDPPorts = [ 4445 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
