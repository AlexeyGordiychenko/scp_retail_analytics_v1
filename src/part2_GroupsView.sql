---Функция, возвращающая таблицу с расчетом фактической маржи по группе для клиента---

CREATE OR REPLACE FUNCTION 
					customer_margin(IN metod VARCHAR DEFAULT 'transactions', 
									IN parameter INT DEFAULT 1e+6) 
RETURNS TABLE (customer_id BIGINT, 
				group_id INT, 
				group_margin NUMERIC) 
AS $$
BEGIN
	IF metod = 'period' THEN
		RETURN QUERY
		SELECT vph.customer_id,
				vph.group_id,
				SUM(group_summ_paid - group_cost) AS group_margin
		FROM v_purchase_history vph
		WHERE transaction_datetime >= analyzed_period() - (interval '1 day') * parameter
		GROUP BY 1, 2
		ORDER BY 1, 2;
	ELSIF metod = 'transactions' THEN
		RETURN QUERY
		SELECT b.customer_id,
				b.group_id,
				SUM(group_summ_paid - group_cost) AS margin
		FROM (SELECT vph.*,
					ROW_NUMBER() OVER (PARTITION BY vph.customer_id ORDER BY transaction_datetime DESC) AS list
				FROM v_purchase_history vph) AS b
		WHERE list <= parameter
		GROUP BY 1, 2
		ORDER BY 1, 2;
	END IF;	
END;				
$$ LANGUAGE PLPGSQL;


DROP VIEW IF EXISTS v_groups;
CREATE OR REPLACE VIEW v_groups AS
WITH affinity_index AS
(SELECT vp.customer_id,
		vp.group_id,
		(SELECT vp.group_purchase  * 1.0 / COUNT(DISTINCT vph.transaction_id)
        FROM v_purchase_history AS vph
        WHERE vph.transaction_datetime BETWEEN vp.first_group_purchase_date 
											AND vp.last_group_purchase_date 
			AND vph.customer_id = vp.customer_id) AS group_affinity_index
FROM v_periods vp	
ORDER BY 1, 2),	
churn_stability_margin AS
(SELECT csm.customer_id,
		csm.group_id,
		group_churn_rate,
		avg(relative_deviation) AS group_stability_index,
		group_margin
FROM (SELECT vph.customer_id,
			vph.group_id,
			(EXTRACT (EPOCH FROM (analyzed_period() - last_group_purchase_date))/86400) / group_frequency AS group_churn_rate,
			ABS((EXTRACT (EPOCH FROM (transaction_datetime - LAG(transaction_datetime) OVER (PARTITION BY vph.customer_id, vph.group_id ORDER BY transaction_datetime)))/86400) - group_frequency) / group_frequency AS relative_deviation,
			group_margin
		FROM v_purchase_history vph
		JOIN v_periods vp ON vph.customer_id = vp.customer_id 
							AND vph.group_id = vp.group_id
		JOIN customer_margin() cm ON vph.customer_id = cm.customer_id
									AND vph.group_id = cm.group_id
		GROUP BY vph.customer_id, vph.group_id, transaction_datetime, last_group_purchase_date, group_frequency, group_margin) AS csm
GROUP BY csm.customer_id, csm.group_id, group_churn_rate, group_margin
ORDER BY 1, 2),
discount AS
(SELECT tr.customer_id, 
		tr.group_id, 
		count_transaction * 1.0 / group_purchase AS group_discount_share,
		MIN(group_min_discount) FILTER (WHERE group_min_discount > 0) AS group_minimum_discount
FROM (SELECT ct.customer_id,
			group_id,
			count(DISTINCT ct.transaction_id) FILTER (WHERE sku_discount > 0) AS count_transaction
		FROM customer_transactions() ct		
		JOIN checks ch ON ct.transaction_id = ch.transaction_id
		JOIN products p ON ch.sku_id = p.sku_id
		GROUP BY 1, 2
		ORDER BY 1, 2) AS tr		
JOIN v_periods vp ON tr.customer_id = vp.customer_id 
					AND tr.group_id = vp.group_id
JOIN v_purchase_history vph ON tr.customer_id = vph.customer_id 
							AND tr.group_id = vph.group_id
GROUP BY 1, 2, 3),
average_discount AS
(SELECT vph.customer_id,
		vph.group_id,
		sum(group_summ_paid) / sum(group_summ) AS group_average_discount
FROM v_purchase_history vph
JOIN products p ON vph.group_id = p.group_id
JOIN checks ch ON vph.transaction_id = ch.transaction_id 
				AND p.sku_id = ch.sku_id
WHERE sku_discount > 0
GROUP BY 1, 2
ORDER BY 1, 2)
SELECT ai.customer_id,
		ai.group_id,
		group_affinity_index,
		group_churn_rate,
		group_stability_index,
		group_margin,
		group_discount_share,
		group_minimum_discount,
		group_average_discount
FROM affinity_index ai
JOIN churn_stability_margin csm ON ai.customer_id = csm.customer_id
								AND ai.group_id = csm.group_id
JOIN discount d ON ai.customer_id = d.customer_id
				AND ai.group_id = d.group_id				
LEFT JOIN average_discount ad ON ai.customer_id = ad.customer_id
								AND ai.group_id = ad.group_id
ORDER BY 1, 2


SELECT *
FROM v_groups;
