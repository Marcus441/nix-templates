{lib, ...}: {
  options.processes = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.shutdown = lib.mkOption {
        type = lib.types.submodule {
          options = {
            signal = lib.mkOption {
              type = lib.types.ints.between 1 31;
              default = 15;
              description = "Unix signal number used for graceful shutdown.";
            };
            grace = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 5;
              description = "Seconds before shutdown escalates to SIGKILL.";
            };
          };
        };
        default = {};
        description = "Graceful shutdown signal and timeout.";
      };
    });
  };

  config = {
    services.postgres = {
      enable = true;
      initialDatabases = [{name = "app";}];
    };

    enterTest = ''
      for _ in $(seq 60); do
        pg_isready --quiet && break
        sleep 1
      done
      pg_isready
      psql --dbname app --command 'create table smoke (n integer)'
      psql --dbname app --command 'insert into smoke values (1)'
      test "$(psql --dbname app --tuples-only --no-align --command 'select n from smoke')" = 1
    '';
  };
}
