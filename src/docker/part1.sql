DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS cards CASCADE;
DROP TABLE IF EXISTS product_groups CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS stores CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS checks CASCADE;
DROP TABLE IF EXISTS analysis_date CASCADE;
DROP TABLE IF EXISTS segments CASCADE;

DROP PROCEDURE IF EXISTS import;
DROP PROCEDURE IF EXISTS export;

SET datestyle = 'ISO, DMY';

-- Create the customers table
CREATE TABLE IF NOT EXISTS customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR NOT NULL CHECK (customer_name ~ '^[A-Za-zА-Яа-яЁё\s\-]+$'),
    customer_surname VARCHAR NOT NULL CHECK (customer_surname ~ '^[A-Za-zА-Яа-яЁё\s\-]+$'),
    customer_primary_email VARCHAR UNIQUE CHECK (
        customer_primary_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'
    ),
    customer_primary_phone VARCHAR UNIQUE CHECK (customer_primary_phone ~ '^\+7[0-9]{10}$')
);

-- Create the Cards table
CREATE TABLE IF NOT EXISTS cards (
    customer_card_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id) NOT NULL
);

-- Create the product_groups table
CREATE TABLE IF NOT EXISTS product_groups (
    group_id SERIAL PRIMARY KEY,
    group_name VARCHAR NOT NULL CHECK (group_name ~ '^[A-Za-zА-Яа-я0-9\s\-\+\=\@\#\$\%\^\&\*\(\)\[\]\{\}\;\:\,\.\<\>\?\/\|\_\~]+$')
);

-- Create the products table
CREATE TABLE IF NOT EXISTS products (
    sku_id SERIAL PRIMARY KEY,
    sku_name VARCHAR NOT NULL CHECK (sku_name ~ '^[A-Za-zА-Яа-я0-9\s\-\+\=\@\#\$\%\^\&\*\(\)\[\]\{\}\;\:\,\.\<\>\?\/\|\_\~]+$'),
    group_id INT REFERENCES product_groups(group_id) NOT NULL
);

-- Create the Stores table
CREATE TABLE IF NOT EXISTS stores (
    transaction_store_id SERIAL NOT NULL,
    sku_id SERIAL REFERENCES products(sku_id) NOT NULL,
    sku_purchase_price NUMERIC NOT NULL CHECK (sku_purchase_price >= 0),
    sku_retail_price NUMERIC NOT NULL CHECK (sku_retail_price >= 0)
);

-- Create the transactions table
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id SERIAL PRIMARY KEY,
    customer_card_id INT REFERENCES Cards(customer_card_id) NOT NULL,
    transaction_summ NUMERIC NOT NULL,
    transaction_datetime TIMESTAMP NOT NULL,
    transaction_store_id SERIAL NOT NULL
);

-- Create the checks table
CREATE TABLE IF NOT EXISTS checks (
    transaction_id INT REFERENCES transactions(transaction_id),
    sku_id INT REFERENCES products(sku_id) NOT NULL,
    sku_amount NUMERIC NOT NULL,
    sku_summ NUMERIC NOT NULL,
    sku_summ_paid NUMERIC NOT NULL,
    sku_discount NUMERIC NOT NULL
);

-- Create the analysis_date table
CREATE TABLE IF NOT EXISTS analysis_date (analysis_formation TIMESTAMP);

CREATE TABLE IF NOT EXISTS segments 
(
	segment BIGINT PRIMARY KEY,
	average_check VARCHAR NOT NULL,
	frequency_of_purchases VARCHAR NOT NULL,
	churn_probability VARCHAR NOT NULL
);

-- Procedure for importing data
CREATE OR REPLACE PROCEDURE import(
  table_name TEXT, file_path TEXT, delimiter TEXT
) LANGUAGE plpgsql AS $$ BEGIN EXECUTE format(
  'COPY %I FROM %L WITH CSV DELIMITER %L', 
  table_name, file_path, delimiter
);
END;
$$;

-- Procedure for exporting data
CREATE OR REPLACE PROCEDURE export(
  table_name TEXT, file_path TEXT, delimiter TEXT
) LANGUAGE plpgsql AS $$ BEGIN EXECUTE format(
  'COPY %I TO %L WITH CSV DELIMITER %L', 
  table_name, file_path, delimiter
);
END;
$$;

DO $$
DECLARE
    -- set to '_Mini' to import mini dataset
    -- set to '' to import- full dataset
    dataset_type TEXT := '';
BEGIN
    CALL import('customers', '/home/Personal_Data' || dataset_type || '.tsv', E'\t');
    CALL import('cards', '/home/Cards' || dataset_type || '.tsv', E'\t');
    CALL import('product_groups', '/home/Groups_SKU' || dataset_type || '.tsv', E'\t');
    CALL import('products', '/home/SKU' || dataset_type || '.tsv', E'\t');
    CALL import('stores', '/home/Stores' || dataset_type || '.tsv', E'\t');
    CALL import('transactions', '/home/Transactions' || dataset_type || '.tsv', E'\t');
    CALL import('checks', '/home/Checks' || dataset_type || '.tsv', E'\t');
    CALL import('analysis_date', '/home/Date_Of_Analysis_Formation.tsv', E'\t');
    CALL import('segments', '/home/Segments.tsv', E'\t');
END $$;

