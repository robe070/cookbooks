# Azure SQL rejects DEFAULT_DATABASE on CREATE LOGIN

The LANSA install C++ (triggered by `SUDB=1`) emits:

```sql
CREATE LOGIN [x] WITH PASSWORD='…', DEFAULT_DATABASE=<db>
```

**Azure SQL Database does not support the `DEFAULT_DATABASE` clause** (native error **40517**,
"keyword or statement option 'default_database' is not supported"). Box / RDS SQL Server (what AWS
uses) does. So an MSI validated on AWS **fails DB setup on Azure**: the `CREATE LOGIN` aborts → the
login/user is never created → the LANSA plugin `lansaweb.dll` can't connect → `w3wp` access-violates
(`0xc0000005`) → `DefaultAppPool` rapid-fails → all URL tests fail.

**Why:** Azure SQL has no server-side default database for a login (logins live in `master` and
can't be bound to a user DB); there is no replacement property.

## Fixes

- **Durable fix (in the LANSA install C++):** gate the clause on
  `SELECT SERVERPROPERTY('EngineEdition')` — **5 = Azure SQL Database**, 8 = Managed Instance. On 5,
  skip `DEFAULT_DATABASE` (and `CREATE DATABASE` / file-path options), then
  `CREATE USER … FOR LOGIN` in the target DB. `SUDB=1` is vital and must stay — it is what creates
  the application tables.
- **Pipeline workaround (no C++ change):** keep `SUDB=1`, let the MSI create the tables, and have
  the **pipeline create the login/user after the MSI install** — login in `master`, then
  `CREATE USER FOR LOGIN` + `db_owner` in the app DB — using pipeline variables (DBSV, dbname, admin
  user/pwd, webuser/pwd), never literals. Idempotent; run for all deployments.

## Diagnosis trail (for next time)

Event 1000 faulting module `lansaweb.dll` + exception `0xc0000005` → LANSA plugin trace
(`X_RUN=ITRO:Y ITRL:4`) → the `CREATE LOGIN` ADO exception.
