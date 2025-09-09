create user replicator with replication encrypted password 'replicator_password';
select pg_create_physical_replication_slot('replication_slot');


GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO replicator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON TABLES TO replicator;
