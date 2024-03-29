--@block
CREATE OR REPLACE FUNCTION analyzed_period()
    RETURNS TIMESTAMP
    AS $$
BEGIN
    RETURN(
        SELECT
            MAX(analysis_formation)
        FROM
            analysis_date);
END;
$$
LANGUAGE PLPGSQL;

--@block
---Функция, возвращающая таблицу со всеми транзакциями клиентов---
CREATE OR REPLACE FUNCTION customer_transactions()
    RETURNS TABLE(
            customer_id BIGINT,
            transaction_id BIGINT,
            customer_card_id BIGINT,
            transaction_summ NUMERIC,
            transaction_datetime TIMESTAMP,
            transaction_store_id BIGINT
        )
        AS $$
    SELECT
        customers.customer_id,
        t.transaction_id,
        cards.customer_card_id,
        t.transaction_summ,
        t.transaction_datetime,
        t.transaction_store_id
    FROM
        customers
        LEFT JOIN cards ON customers.customer_id = cards.customer_id
        LEFT JOIN transactions t ON cards.customer_card_id = t.customer_card_id
    WHERE
        COALESCE(t.transaction_datetime, analyzed_period()) <= analyzed_period()
$$
LANGUAGE SQL;

--@block
---Функция, возвращающая таблицу с основным магазином для каждого клиента---
CREATE OR REPLACE FUNCTION main_store()
    RETURNS TABLE(
            customer_id BIGINT,
            main_store BIGINT
        )
        AS $$
    WITH customers_shops_last3 AS(
        SELECT
            customer_id,
            transaction_store_id
        FROM(
            SELECT
                customer_id,
                transaction_store_id,
                ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY transaction_datetime DESC) AS rn
        FROM
            customer_transactions())
    WHERE
        rn BETWEEN 1 AND 3
    GROUP BY
        customer_id, transaction_store_id
    HAVING
        COUNT(transaction_store_id) = 3
),
customers_shops_transactions_rate AS(
    SELECT
        customer_id,
        transaction_store_id
    FROM(
        SELECT
            customer_id,
            transaction_store_id,
            ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY COUNT(transaction_store_id) DESC,
                MAX(transaction_datetime) DESC) AS rn
    FROM
        customer_transactions()
    GROUP BY
        customer_id, transaction_store_id)
    WHERE
        rn = 1
)
SELECT
    *
FROM
    customers_shops_transactions_rate
EXCEPT
SELECT
    *
FROM
    customers_shops_last3
UNION
SELECT
    *
FROM
    customers_shops_last3
$$
LANGUAGE SQL;

--@block
CREATE OR REPLACE VIEW v_customers AS
WITH check_frequency_churn AS (
    SELECT
        customer_id,
        customer_average_check,
        customer_frequency,
        customer_inactive_period,
        not_null,
        CASE WHEN COALESCE(customer_frequency, 0) = 0 THEN
            NULL
        ELSE
            customer_inactive_period / customer_frequency
        END AS customer_churn_rate,
        PERCENT_RANK() OVER (PARTITION BY customer_frequency IS NOT NULL ORDER BY customer_frequency DESC) AS pr_f,
        PERCENT_RANK() OVER (PARTITION BY customer_average_check IS NOT NULL ORDER BY customer_average_check) AS pr_ac,
        COUNT(
            CASE WHEN not_null THEN
                1
            END) OVER () AS total
    FROM (
        SELECT
            customer_id,
            BOOL_OR(transaction_id IS NOT NULL) AS not_null,
            AVG(transaction_summ) AS customer_average_check,
            EXTRACT(EPOCH FROM (MAX(transaction_datetime) - MIN(transaction_datetime)) / 86400) / COUNT(transaction_id) AS customer_frequency,
            EXTRACT(EPOCH FROM (analyzed_period() - MAX(transaction_datetime)) / 86400) AS customer_inactive_period
        FROM
            customer_transactions()
        GROUP BY
            customer_id) AS data
),
check_frequency_churn_segment AS (
    SELECT
        customer_id,
        customer_average_check,
        CASE WHEN customer_average_check IS NULL THEN
            NULL
        WHEN pr_ac >= 0.9 THEN
            'High'
        WHEN pr_ac >= 0.65 THEN
            'Medium'
        ELSE
            'Low'
        END AS customer_average_check_segment,
        customer_frequency,
        CASE WHEN customer_frequency IS NULL THEN
            NULL
        WHEN pr_f >= 0.9 THEN
            'Often'
        WHEN pr_f >= 0.65 THEN
            'Occasionally'
        ELSE
            'Rarely'
        END AS customer_frequency_segment,
        customer_inactive_period,
        customer_churn_rate,
        CASE WHEN customer_churn_rate IS NULL THEN
            NULL
        WHEN customer_churn_rate BETWEEN 0 AND 2 THEN
            'Low'
        WHEN customer_churn_rate BETWEEN 2 AND 5 THEN
            'Medium'
        ELSE
            'High'
        END AS customer_churn_segment
    FROM
        check_frequency_churn
)
SELECT
    data.*,
    s.segment AS customer_segment,
    ms.main_store AS customer_primary_store
FROM
    check_frequency_churn_segment data
    LEFT JOIN segments s ON data.customer_average_check_segment = s.average_check
        AND data.customer_frequency_segment = s.frequency_of_purchases
        AND data.customer_churn_segment = s.churn_probability
    LEFT JOIN main_store() ms ON data.customer_id = ms.customer_id
ORDER BY data.customer_id;
