--@block
CREATE OR REPLACE VIEW v_periods AS
SELECT
    customer_id,
    vph.group_id,
    MIN(transaction_datetime) AS first_group_purchase_date,
    MAX(transaction_datetime) AS last_group_purchase_date,
    NULLIF(COUNT(DISTINCT vph.transaction_id), 0) AS group_purchase,
    (EXTRACT(EPOCH FROM (MAX(transaction_datetime) - MIN(transaction_datetime)) / 86400) + 1) / COUNT(DISTINCT vph.transaction_id) AS group_frequency,
    CASE WHEN vph.group_id IS NOT NULL THEN
        COALESCE(MIN(min_discount.min_discount), 0)
    END AS group_min_discount
FROM
    v_purchase_history vph
    LEFT JOIN (
        SELECT
            transaction_id,
            group_id,
            MIN(sku_discount / sku_summ) AS min_discount
        FROM
            checks c
            JOIN products p ON c.sku_id = p.sku_id
        WHERE
            sku_discount <> 0
            AND sku_summ <> 0
        GROUP BY
            transaction_id, group_id) AS min_discount ON vph.transaction_id = min_discount.transaction_id
    AND vph.group_id = min_discount.group_id
GROUP BY
    customer_id, vph.group_id;
