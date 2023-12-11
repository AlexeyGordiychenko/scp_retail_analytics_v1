--@block
CREATE OR REPLACE VIEW v_purchase_history AS
SELECT
    customer_id,
    ct.transaction_id,
    transaction_datetime,
    group_id,
    SUM(sku_amount * sku_purchase_price) AS group_cost,
    SUM(sku_summ) AS group_summ,
    SUM(sku_summ_paid) AS group_summ_paid
FROM
    customer_transactions() ct
    LEFT JOIN checks ch ON ct.transaction_id = ch.transaction_id
    LEFT JOIN products p ON ch.sku_id = p.sku_id
    LEFT JOIN stores s ON ct.transaction_store_id = s.transaction_store_id
        AND ch.sku_id = s.sku_id
GROUP BY
    customer_id, ct.transaction_id, transaction_datetime, group_id;
