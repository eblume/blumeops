{
  disko.devices = {
    disk = {
      nvme = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0M618703B";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
      games = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_1TB_S3PJNF0J903900Z";
        content = {
          type = "gpt";
          partitions = {
            games = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/mnt/games";
              };
            };
          };
        };
      };
      storage1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S21HNSAG423014P";
        content = {
          type = "gpt";
          partitions = {
            storage1 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/mnt/storage1";
              };
            };
          };
        };
      };
    };
  };
}
