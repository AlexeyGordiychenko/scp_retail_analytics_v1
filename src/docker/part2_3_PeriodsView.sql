CREATE OR REPLACE VIEW v_periods AS
SELECT
    customer_id,
    vph.group_id,
    min(transaction_datetime) AS first_group_purchase_date,
    max(transaction_datetime) AS last_group_purchase_date,
    count(DISTINCT vph.transaction_id) AS group_purchase,
	(EXTRACT(EPOCH FROM (max(transaction_datetime) - min(transaction_datetime)) / 86400) + 1) / count(DISTINCT vph.transaction_id) AS group_frequency,
    coalesce(min(min_discount.min_discount), 0) AS group_min_discount
FROM
    v_purchase_history vph
    LEFT JOIN (
        SELECT
            transaction_id,
            group_id,
            min(sku_discount / sku_summ) AS min_discount
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

