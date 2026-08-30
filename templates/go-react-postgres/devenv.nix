{pkgs, ...}: {
  packages = [pkgs.curl];

  languages.go.enable = true;

  languages.javascript = {
    enable = true;
    npm.enable = true;
    directory = "web";
  };

  languages.typescript.enable = true;

  services.postgres = {
    enable = true;
    initialDatabases = [{name = "app";}];
  };

  processes.api = {
    exec = "go run ./cmd/api -addr 127.0.0.1:5080";
    after = ["devenv:processes:postgres"];
    ready.http.get = {
      port = 5080;
      path = "/health";
    };
  };

  processes.web = {
    exec = ''
      if [ ! -f web/package.json ]; then
        echo "no web/ yet - run: npm create vite@latest web -- --template react-ts"
        exit 0
      fi
      exec npm --prefix web run dev
    '';
    after = ["devenv:processes:api"];
  };

  enterTest = ''
    wait_for_port 5080 600
    curl -sf http://127.0.0.1:5080/health | grep -q '"db":1'
  '';
}
