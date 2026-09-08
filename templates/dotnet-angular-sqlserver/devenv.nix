{pkgs, ...}: {
  packages = [pkgs.curl pkgs.sqlcmd pkgs.docker-client];

  languages.dotnet = {
    enable = true;
    package = pkgs.dotnetCorePackages.sdk_10_0;
    lsp = {
      enable = true;
      package = pkgs.roslyn-ls;
    };
  };

  languages.javascript = {
    enable = true;
    npm.enable = true;
    npm.install.enable = true;
  };

  languages.typescript.enable = true;

  env = {
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    DOTNET_NOLOGO = "1";
    MSSQL_RUNTIME = "docker";
    MSSQL_IMAGE = "mcr.microsoft.com/mssql/server:2022-latest";
    MSSQL_PORT = "1433";
    MSSQL_DATABASE = "app";
  };

  scripts.mssql-password.exec = ''
    set -eu
    file="$DEVENV_STATE/mssql/sa-password"
    if [ ! -s "$file" ]; then
      mkdir -p "$DEVENV_STATE/mssql"
      umask 077
      printf 'Dev-%s' "$(head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)" >"$file"
    fi
    cat "$file"
  '';

  scripts.mssql.exec = ''
    exec sqlcmd -S "127.0.0.1,$MSSQL_PORT" -U sa -P "$(mssql-password)" -C "$@"
  '';

  scripts.mssql-connection-string.exec = ''
    printf 'Server=127.0.0.1,%s;Database=%s;User Id=sa;Password=%s;TrustServerCertificate=True;Encrypt=False' \
      "$MSSQL_PORT" "$MSSQL_DATABASE" "$(mssql-password)"
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

  processes.api = {
    exec = ''
      export ConnectionStrings__Default="$(mssql-connection-string)"
      exec dotnet run --project apps/api/src/Api --urls http://127.0.0.1:5080
    '';
    after = ["devenv:processes:sqlserver"];
    ready.http.get = {
      port = 5080;
      path = "/health";
    };
  };

  processes.web = {
    exec = "npm run start --workspace apps/web";
    after = ["devenv:processes:api"];
  };

  enterTest = ''
    wait_for_port "$MSSQL_PORT" 900
    wait_for_port 5080 900
    curl -sf http://127.0.0.1:5080/health | grep -q '"db":1'
    curl -sf -X POST http://127.0.0.1:5080/items -H 'content-type: application/json' -d '{"name":"smoke"}'
    curl -sf http://127.0.0.1:5080/items | grep -q smoke
  '';
}
