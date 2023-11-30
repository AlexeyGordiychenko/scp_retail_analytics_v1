DROP VIEW IF EXISTS v_periods;
CREATE OR REPLACE VIEW v_periods AS
SELECT customer_id,
		vph.group_id,
		min(transaction_datetime) AS first_group_purchase_date,
		max(transaction_datetime) AS last_group_purchase_date,
		count(DISTINCT vph.transaction_id) AS group_purchase,
		(EXTRACT (EPOCH FROM (max(transaction_datetime) - min(transaction_datetime))/86400) + 1) / count(DISTINCT vph.transaction_id) AS group_frequency,
		(CASE 
			WHEN max(sku_discount / sku_summ) = 0 THEN '0'  
			ELSE min(sku_discount / sku_summ) FILTER (WHERE sku_discount / sku_summ > 0)
		END) AS group_min_discount
FROM v_purchase_history vph
JOIN products p ON vph.group_id = p.group_id
JOIN checks ch ON vph.transaction_id = ch.transaction_id 
				AND p.sku_id = ch.sku_id
GROUP BY customer_id, vph.group_id
ORDER BY 1, 2;		

SELECT *
FROM v_periods;
