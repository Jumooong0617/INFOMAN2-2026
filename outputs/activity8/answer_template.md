# Activity 8 Answer Template

## Part 1: Star Schema Design

### 1. Fact Table Grain

- One row per sales transaction (sales_txn.id). This allows detailed transaction-level analysis and aggregations at any time granularity.

### 2. Fact Measures

- qty – quantity sold
- unit_price – unit price of product
- total_amount – derived measure: qty * unit_price

### 3. Dimension Tables and Attributes

- `dim_date`: date_key (PK, surrogate), full_date (source, UNIQUE), day_of_week, day_name, day_of_month, month_num, month_name, quarter, year, is_weekend
- `dim_customer`: customer_key (PK, surrogate), source_id (customers.id, UNIQUE), full_name, region_code
- `dim_product`: product_key (PK, surrogate), source_id (products.id, UNIQUE), product_name, category, unit_price
- `dim_branch`: branch_key (PK, surrogate), source_id (branches.id, UNIQUE), branch_name, city, region

### 4. Relationship Summary

- fact_sales.date_key → dim_date.date_key
- fact_sales.customer_key → dim_customer.customer_key
- fact_sales.product_key → dim_product.product_key
- fact_sales.branch_key → dim_branch.branch_key

## Part 2: Warehouse DDL

```sql
-- Schema
CREATE SCHEMA IF NOT EXISTS dw;

-- dim_date (calendar dimension)
CREATE TABLE IF NOT EXISTS dw.dim_date (
    date_key        SERIAL          PRIMARY KEY,
    full_date       DATE            NOT NULL UNIQUE,
    day_of_week     SMALLINT        NOT NULL,
    day_name        VARCHAR(10)     NOT NULL,
    day_of_month    SMALLINT        NOT NULL,
    month_num       SMALLINT        NOT NULL,
    month_name      VARCHAR(10)     NOT NULL,
    quarter         SMALLINT        NOT NULL,
    year            SMALLINT        NOT NULL,
    is_weekend      BOOLEAN         NOT NULL DEFAULT FALSE
);

-- dim_customer
CREATE TABLE IF NOT EXISTS dw.dim_customer (
    customer_key    SERIAL          PRIMARY KEY,
    source_id       INT             NOT NULL UNIQUE,
    full_name       VARCHAR(200)    NOT NULL,
    region_code     VARCHAR(20)
);

-- dim_product
CREATE TABLE IF NOT EXISTS dw.dim_product (
    product_key     SERIAL          PRIMARY KEY,
    source_id       INT             NOT NULL UNIQUE,
    product_name    VARCHAR(200)    NOT NULL,
    category        VARCHAR(100),
    unit_price      NUMERIC(10,2)   NOT NULL
);

-- dim_branch
CREATE TABLE IF NOT EXISTS dw.dim_branch (
    branch_key      SERIAL          PRIMARY KEY,
    source_id       INT             NOT NULL UNIQUE,
    branch_name     VARCHAR(200)    NOT NULL,
    city            VARCHAR(100),
    region          VARCHAR(100)
);

-- fact_sales (grain: one row per sales_txn)
CREATE TABLE IF NOT EXISTS dw.fact_sales (
    sales_key       BIGSERIAL       PRIMARY KEY,
    source_txn_id   INT             NOT NULL UNIQUE,
    date_key        INT             NOT NULL REFERENCES dw.dim_date(date_key),
    customer_key    INT             NOT NULL REFERENCES dw.dim_customer(customer_key),
    product_key     INT             NOT NULL REFERENCES dw.dim_product(product_key),
    branch_key      INT             NOT NULL REFERENCES dw.dim_branch(branch_key),
    qty             INT             NOT NULL,
    unit_price      NUMERIC(10,2)   NOT NULL,
    gross_revenue   NUMERIC(12,2)   GENERATED ALWAYS AS (qty * unit_price) STORED
);

-- etl_log
CREATE TABLE IF NOT EXISTS dw.etl_log (
    log_id          SERIAL          PRIMARY KEY,
    run_ts          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    status          VARCHAR(10)     NOT NULL CHECK (status IN ('SUCCESS','FAIL')),
    rows_loaded     INT,
    error_message   TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dim_customer_source  ON dw.dim_customer(source_id);
CREATE INDEX IF NOT EXISTS idx_dim_product_source   ON dw.dim_product(source_id);
CREATE INDEX IF NOT EXISTS idx_dim_branch_source    ON dw.dim_branch(source_id);
CREATE INDEX IF NOT EXISTS idx_dim_date_fulldate    ON dw.dim_date(full_date);
CREATE INDEX IF NOT EXISTS idx_fact_date_key        ON dw.fact_sales(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_branch_key      ON dw.fact_sales(branch_key);
CREATE INDEX IF NOT EXISTS idx_fact_product_key     ON dw.fact_sales(product_key);
CREATE INDEX IF NOT EXISTS idx_fact_customer_key    ON dw.fact_sales(customer_key);
CREATE INDEX IF NOT EXISTS idx_fact_date_branch     ON dw.fact_sales(date_key, branch_key);
```

## Part 3: ETL Procedure

### 1. Procedure Code

```sql
CREATE OR REPLACE PROCEDURE dw.run_sales_etl()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_loaded   INT := 0;
    v_bad_rows      INT := 0;
BEGIN
    -- Step 1-4: Upsert dimensions (see etl_procedure.sql for full code)
    -- ...

    -- Step 5: Data quality check
    SELECT COUNT(*) INTO v_bad_rows
    FROM public.sales_txn s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.fact_sales f WHERE f.source_txn_id = s.id
    )
    AND (
           s.qty        <= 0
        OR s.unit_price <= 0
        OR s.customer_id IS NULL
        OR s.product_id  IS NULL
        OR s.branch_id   IS NULL
        OR s.txn_date    IS NULL
    );

    -- Step 6: Incremental fact load
    INSERT INTO dw.fact_sales (
        source_txn_id, date_key, customer_key, product_key, branch_key, qty, unit_price
    )
    SELECT s.id, dd.date_key, dc.customer_key, dp.product_key, db.branch_key, s.qty, s.unit_price
    FROM public.sales_txn s
    JOIN dw.dim_date     dd ON dd.full_date = s.txn_date::DATE
    JOIN dw.dim_customer dc ON dc.source_id = s.customer_id
    JOIN dw.dim_product  dp ON dp.source_id = s.product_id
    JOIN dw.dim_branch   db ON db.source_id = s.branch_id
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.fact_sales f WHERE f.source_txn_id = s.id
    )
    AND s.qty > 0 AND s.unit_price > 0
    AND s.customer_id IS NOT NULL AND s.product_id IS NOT NULL
    AND s.branch_id IS NOT NULL AND s.txn_date IS NOT NULL;

    GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;

    -- Step 7: Log success
    INSERT INTO dw.etl_log (run_ts, status, rows_loaded, error_message)
    VALUES (NOW(), 'SUCCESS', v_rows_loaded, NULL);

EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO dw.etl_log (run_ts, status, rows_loaded, error_message)
        VALUES (NOW(), 'FAIL', 0, SQLERRM);
        RAISE;
END;
$$;
```

### 2. Procedure Execution

```sql
CALL dw.run_sales_etl();
```

### 3. ETL Log Output

```sql
SELECT * FROM dw.etl_log ORDER BY run_ts DESC;
```

```txt
-- Paste output here
```

## Part 4: Analytical Queries

### Query 1: Monthly Revenue by Branch Region

```sql
-- SQL here
```

Interpretation:

<1-2 sentence interpretation>

### Query 2: Top 5 Products by Total Revenue

```sql
-- SQL here
```

Interpretation:

<1-2 sentence interpretation>

### Query 3: Customer Region Contribution to Sales

```sql
-- SQL here
```

Interpretation:

<1-2 sentence interpretation>