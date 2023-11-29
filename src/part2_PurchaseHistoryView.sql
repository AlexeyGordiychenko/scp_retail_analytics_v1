DROP VIEW IF EXISTS v_purchase_history;
CREATE OR REPLACE VIEW v_purchase_history AS
SELECT DISTINCT customer_id, 
				ct.transaction_id, 
				transaction_datetime,
				group_id,
				sum(sku_amount * sku_purchase_price) OVER w AS group_cost,
				sum(sku_summ) OVER w AS group_summ,
				sum(sku_summ_paid) OVER w AS group_summ_paid 
FROM customer_transactions() ct
JOIN checks ch ON ct.transaction_id = ch.transaction_id
JOIN products p ON ch.sku_id = p.sku_id 
JOIN stores s ON ch.sku_id = s.sku_id 
				AND ct.transaction_store_id = s.transaction_store_id
WINDOW w AS (PARTITION BY customer_id, ct.transaction_id, group_id)
ORDER BY customer_id, transaction_id, group_id;

SELECT *
FROM v_purchase_history;
