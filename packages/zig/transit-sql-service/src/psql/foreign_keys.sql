SELECT true as sametable, conname,
  pg_catalog.pg_get_constraintdef(r.oid, true) as condef,
  conrelid::pg_catalog.regclass AS ontable
FROM pg_catalog.pg_constraint r
WHERE r.conrelid = TRANSIT_OBJECT AND r.contype = 'f'
     AND conparentid = 0
ORDER BY conname
