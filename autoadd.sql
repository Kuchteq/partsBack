CREATE OR REPLACE FUNCTION parts_tsvector_trigger() RETURNS trigger AS $$
begin
 new.document_with_weights :=
  setweight(to_tsvector(new.name), 'A') ||
  setweight(to_tsvector(coalesce(new.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(suppliers.name, '')), 'C') ||
  setweight(to_tsvector(coalesce(segments.name, '')), 'D') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.purchase_date :: DATE, 'dd/mm/yyyy'), '')), 'D')
  FROM suppliers, segments WHERE new.supplier_id = suppliers.id AND new.segment_id = segments.id;
  return new;
end
  
$$ LANGUAGE plpgsql;

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
    ON parts FOR EACH ROW EXECUTE PROCEDURE parts_tsvector_trigger();



CREATE OR REPLACE FUNCTION computers_tsvector_trigger() RETURNS trigger AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.name), 'A') ||
  setweight(to_tsvector(coalesce(new.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.assembled_at :: DATE, 'dd/mm/yyyy'), '')), 'C');
  return new;
end
  
$$ LANGUAGE plpgsql;

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
    ON computers FOR EACH ROW EXECUTE PROCEDURE computers_tsvector_trigger();


CREATE OR REPLACE FUNCTION clients_tsvector_trigger() RETURNS trigger AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.name), 'A') ||
  setweight(to_tsvector(coalesce(new.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(CAST(new.phone as varchar(128)), '')), 'B') ||
  setweight(to_tsvector(coalesce(new.email, '')), 'B') ||
  setweight(to_tsvector(coalesce(new.nip, '')), 'B') ||
  setweight(to_tsvector(coalesce(new.adress, '')), 'C') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.join_date :: DATE, 'dd/mm/yyyy'), '')), 'D');
  return new;
end
  
$$ LANGUAGE plpgsql;

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
    ON clients FOR EACH ROW EXECUTE PROCEDURE clients_tsvector_trigger();


CREATE OR REPLACE FUNCTION suppliers_tsvector_trigger() RETURNS trigger AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.name), 'A') ||
  setweight(to_tsvector(coalesce(new.short_note, '')), 'C') ||
  setweight(to_tsvector(coalesce(CAST(new.phone as varchar(128)), '')), 'C') ||
  setweight(to_tsvector(coalesce(new.email, '')), 'B') ||
  setweight(to_tsvector(coalesce(new.website, '')), 'B') ||
  setweight(to_tsvector(coalesce(new.nip, '')), 'B') ||
  setweight(to_tsvector(coalesce(new.adress, '')), 'C') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.join_date :: DATE, 'dd/mm/yyyy'), '')), 'D');
  return new;
end
  
$$ LANGUAGE plpgsql;

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
    ON suppliers FOR EACH ROW EXECUTE PROCEDURE suppliers_tsvector_trigger();


CREATE OR REPLACE FUNCTION problems_tsvector_trigger() RETURNS trigger AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.problem_note), 'A') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.hand_in_date :: DATE, 'dd/mm/yyyy'), '')), 'B') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.deadline_date :: DATE, 'dd/mm/yyyy'), '')), 'B');
  return new;
end
  
$$ LANGUAGE plpgsql;

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
    ON problems FOR EACH ROW EXECUTE PROCEDURE problems_tsvector_trigger();





CREATE OR REPLACE FUNCTION history_tsvector_trigger() RETURNS trigger AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.details), 'A') ||
setweight(to_tsvector(coalesce(TO_CHAR(new.at_time :: DATE, 'dd/mm/yyyy'), '')), 'C');
  return new;
end
  
$$ LANGUAGE plpgsql;

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
    ON history FOR EACH ROW EXECUTE PROCEDURE history_tsvector_trigger();





CREATE OR REPLACE FUNCTION orders_tsvector_trigger() RETURNS trigger AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.name), 'B');
  return new;
end
  
$$ LANGUAGE plpgsql;

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
    ON orders FOR EACH ROW EXECUTE PROCEDURE orders_tsvector_trigger();