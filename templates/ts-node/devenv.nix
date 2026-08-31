{pkgs, ...}: {
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_24;
    npm.enable = true;
  };

  languages.typescript.enable = true;

  enterTest = ''
    npm ci
    npm test
    npm run build
  '';
}
