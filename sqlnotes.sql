/* Parts weights adjust */

ALTER TABLE parts
  ADD COLUMN document_with_weights tsvector;
update parts
set document_with_weights = setweight(to_tsvector(parts.name), 'A') ||
  setweight(to_tsvector(coalesce(parts.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(suppliers.name, '')), 'C') ||
  setweight(to_tsvector(coalesce(segments.name, '')), 'D') ||
  setweight(to_tsvector(coalesce(TO_CHAR(parts.purchase_date :: DATE, 'dd/mm/yyyy'), '')), 'D')
FROM suppliers, segments WHERE parts.supplier_id = suppliers.id AND parts.segment_id = segments.id;

CREATE INDEX document_weights_idx ON parts
USING GIN (document_with_weights);

/* Computers weights adjust */

ALTER TABLE computers
  ADD COLUMN document_with_weights tsvector;
update computers
set document_with_weights = setweight(to_tsvector(computers.name), 'A') ||
  setweight(to_tsvector(coalesce(computers.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(TO_CHAR(computers.assembled_at :: DATE, 'dd/mm/yyyy'), '')), 'C')

CREATE INDEX document_weights_idx ON computers
USING GIN (document_with_weights);

/* Clients weights adjust */

ALTER TABLE clients
  ADD COLUMN document_with_weights tsvector;
update clients
set document_with_weights = setweight(to_tsvector(clients.name), 'A') ||
  setweight(to_tsvector(coalesce(clients.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(CAST(clients.phone as varchar(128)), '')), 'B') ||
  setweight(to_tsvector(coalesce(clients.email, '')), 'B') ||
  setweight(to_tsvector(coalesce(clients.nip, '')), 'B') ||
  setweight(to_tsvector(coalesce(clients.adress, '')), 'C') ||
  setweight(to_tsvector(coalesce(TO_CHAR(clients.join_date :: DATE, 'dd/mm/yyyy'), '')), 'D')

/* Suppliers weights adjust */

  ALTER TABLE suppliers
  ADD COLUMN document_with_weights tsvector;
update suppliers
set document_with_weights = setweight(to_tsvector(suppliers.name), 'A') ||
  setweight(to_tsvector(coalesce(suppliers.short_note, '')), 'C') ||
  setweight(to_tsvector(coalesce(CAST(suppliers.phone as varchar(128)), '')), 'C') ||
  setweight(to_tsvector(coalesce(suppliers.email, '')), 'B') ||
  setweight(to_tsvector(coalesce(suppliers.website, '')), 'B') ||
  setweight(to_tsvector(coalesce(suppliers.nip, '')), 'B') ||
  setweight(to_tsvector(coalesce(suppliers.adress, '')), 'C') ||
  setweight(to_tsvector(coalesce(TO_CHAR(suppliers.join_date :: DATE, 'dd/mm/yyyy'), '')), 'D')

/* Problems weights adjust */

ALTER TABLE problems
  ADD COLUMN document_with_weights tsvector;
update problems
set document_with_weights = setweight(to_tsvector(problems.problem_note), 'A') ||
  setweight(to_tsvector(coalesce(TO_CHAR(problems.hand_in_date :: DATE, 'dd/mm/yyyy'), '')), 'B') ||
  setweight(to_tsvector(coalesce(TO_CHAR(problems.deadline_date :: DATE, 'dd/mm/yyyy'), '')), 'B') 