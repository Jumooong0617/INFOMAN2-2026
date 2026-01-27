--TASK 1 
CREATE OR REPLACE FUNCTION log_product_changes()
RETURNS TRIGGER AS $$
BEGIN

	IF (TG_OP = 'INSERT') THEN INSERT INTO products_audit(product_id, change_type, new_name, new_price) VALUES (NEW.product_id, 'INSERT', NEW.name, NEW.price);

	RETURN NEW;
	ELSIF (TG_OP = 'DELETE') THEN INSERT into products_audit(product_id, change_type, old_name, old_price) VALUES (OLD.product_id, 'DELETE', OLD.name, OLD.price);

	RETURN OLD;
	ELSIF (TG_OP = 'UPDATE' AND (OLD.name IS DISTINCT FROM NEW.name OR OLD.price IS DISTINCT FROM NEW.price)) THEN INSERT INTO products_audit(product_id, change_type, old_name, new_name, old_price, new_price) VALUES (NEW.product_id, 'UPDATE', OLD.name, NEW.name, OLD.price, NEW.price);

	RETURN NEW;

END IF;
RETURN NULL;

END;
$$ LANGUAGE plpgsql;

--TASK 2

CREATE TRIGGER product_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON products
FOR EACH ROW
EXECUTE FUNCTION log_product_changes();

-- BONUS CHALLENGES
-- 1. Create the trigger function
CREATE OR REPLACE FUNCTION set_last_modified()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create the trigger
CREATE TRIGGER set_last_modified_trigger
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION set_last_modified();

--3. BEFORE UPDATE is used so that last_modified is updated before the row is 
-- saved, ensuring the timestamp changes during the update; using AFTER UPDATE 
-- would not work because the row is already written.

--4. TESTING
UPDATE products
SET price = 15.99
WHERE name = 'Basic Gizmo';

SELECT name, price, last_modified
FROM products
WHERE name = 'Basic Gizmo';

