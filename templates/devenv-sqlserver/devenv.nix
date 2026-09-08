{pkgs, ...}: {
  packages = [pkgs.sqlcmd pkgs.docker-client];

  env = {
    MSSQL_RUNTIME = "docker";
    MSSQL_IMAGE = "mcr.microsoft.com/mssql/server:2022-latest";
    MSSQL_PORT = "1433";
    MSSQL_DATABASE = "app";
  };

  scripts.mssql-password.exec = ''
    set -eu
    if [ -n "''${MSSQL_SA_PASSWORD:-}" ]; then
      printf '%s' "$MSSQL_SA_PASSWORD"
      exit 0
    fi
    file="$DEVENV_STATE/mssql/sa-password"
    if [ ! -s "$file" ]; then
      mkdir -p "$DEVENV_STATE/mssql"
      (
        umask 077
        printf 'Dev-%s' "$(head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)" >"$file"
      )
    fi
    cat "$file"
  '';

  scripts.mssql.exec = ''
    exec sqlcmd -S "127.0.0.1,$MSSQL_PORT" -U sa -P "$(mssql-password)" -C "$@"
  '';

  scripts.mssql-create-database.exec = ''
    set -eu
    mssql -Q "IF DB_ID(N'$MSSQL_DATABASE') IS NULL BEGIN DECLARE @sql nvarchar(max) = N'CREATE DATABASE ' + QUOTENAME(N'$MSSQL_DATABASE'); EXEC sp_executesql @sql; END"
  '';

  processes.sqlserver = {
    exec = ''
      name="$(basename "$DEVENV_ROOT")-mssql"

      stop() {
        "$MSSQL_RUNTIME" rm --force "$name" >/dev/null 2>&1 || true
      }
      trap stop EXIT HUP INT TERM

      stop
      "$MSSQL_RUNTIME" volume create "$name-data" >/dev/null
      "$MSSQL_RUNTIME" pull "$MSSQL_IMAGE"

      "$MSSQL_RUNTIME" run --rm --name "$name" \
        --platform linux/amd64 \
        --env ACCEPT_EULA=Y \
        --env MSSQL_PID=Developer \
        --env MSSQL_SA_PASSWORD="$(mssql-password)" \
        --publish "127.0.0.1:$MSSQL_PORT:1433" \
        --volume "$name-data:/var/opt/mssql" \
        "$MSSQL_IMAGE" &

      wait $!
    '';
    ready = {
      exec = ''mssql -Q "SELECT 1" >/dev/null'';
      initial_delay = 15;
      period = 5;
      probe_timeout = 10;
      failure_threshold = 240;
    };
  };

  processes.sqlserver-init = {
    exec = "mssql-create-database";
    after = ["devenv:processes:sqlserver"];
  };

  enterTest = ''
    wait_for_port "$MSSQL_PORT" 900
    mssql-create-database
    mssql -d "$MSSQL_DATABASE" -Q 'drop table if exists smoke'
    mssql -d "$MSSQL_DATABASE" -Q 'create table smoke (n integer)'
    mssql -d "$MSSQL_DATABASE" -Q 'insert into smoke values (1)'
    test "$(mssql -d "$MSSQL_DATABASE" -h -1 -W -Q 'set nocount on; select n from smoke')" = 1
  '';
}
