{pkgs, ...}: {
  packages = [pkgs.curl];

  languages.go.enable = true;

  languages.javascript = {
    enable = true;
    npm.enable = true;
    npm.install.enable = true;
  };

  languages.typescript.enable = true;

  services.postgres = {
    enable = true;
    initialDatabases = [{name = "app";}];
  };

  processes.api = {
    exec = "cd apps/api && go run ./cmd/api -addr 127.0.0.1:5080";
    after = ["devenv:processes:postgres"];
    ready.http.get = {
      port = 5080;
      path = "/health";
    };
  };

  processes.web = {
    exec = "npm run dev --workspace apps/web";
    after = ["devenv:processes:api"];
  };

  enterTest = ''
    wait_for_port 5080 600
    curl -sf http://127.0.0.1:5080/health | grep -q '"db":1'
    curl -sf -X POST http://127.0.0.1:5080/items -H 'content-type: application/json' -d '{"name":"smoke"}'
    curl -sf http://127.0.0.1:5080/items | grep -q smoke
  '';
}
