{...}: {
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
}
