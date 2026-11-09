CREATE TABLE "first_items" ( id BIGINT PRIMARY KEY );
INSERT INTO "first_items" VALUES ( 7 );
CREATE TABLE "second_items" ( id BIGINT PRIMARY KEY );
INSERT INTO "second_items" VALUES ( 9 );
UPDATE first_items SET id = 8 WHERE id = 7;
DELETE FROM second_items WHERE id = 100;
SELECT * FROM first_items;
SELECT * FROM second_items;
