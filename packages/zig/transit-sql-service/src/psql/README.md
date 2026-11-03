# psql catalog query templates

These SQL shapes were captured with `psql` 18.6 `--echo-hidden` against PostgreSQL
18.6 for `\d`, `\dn`, `\l` and `\d items`, with a plain Table and primary key.
The upstream owner is
[psql describe.c](https://github.com/postgres/postgres/blob/REL_18_STABLE/src/bin/psql/describe.c).

`TRANSIT_OBJECT` marks an exact quoted decimal object reference. All occurrences
in one statement must identify the same full-width Transit object. Listing
predicates are parsed explicitly by `PgCatalogSql`; changing other tokens or
appending SQL rejects. Templates describe the selected upstream client's SQL,
not persisted Transit definitions or a generic PostgreSQL system catalog.

The installed-client checks in `tests/interfaces/sql_wire/psql.py` generate their
own queries with the pinned client and assert independently chosen observations.
They do not read these production templates as an oracle.
