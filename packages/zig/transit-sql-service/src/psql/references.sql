SELECT conname, conrelid::pg_catalog.regclass AS ontable,
       pg_catalog.pg_get_constraintdef(oid, true) AS condef
  FROM pg_catalog.pg_constraint c
 WHERE confrelid IN (SELECT pg_catalog.pg_partition_ancestors(TRANSIT_OBJECT)
                     UNION ALL VALUES (TRANSIT_OBJECT::pg_catalog.regclass))
       AND contype = 'f' AND conparentid = 0
ORDER BY conname;
