CREATE OR REPLACE FUNCTION personal_offers_visits (first_date TIMESTAMP,
													last_date TIMESTAMP,
													number_transactions INT,
													max_churn_index NUMERIC,
													max_share_transactions_with_discount NUMERIC,
													margin_share NUMERIC)
RETURNS TABLE (customer_id BIGINT,
				start_date TIMESTAMP,
				end_date TIMESTAMP,
				required_transactions_count INT,
				group_name VARCHAR,
				offer_discount_depth INT
				)
AS $$
BEGIN
	RETURN QUERY
	WITH max_discount AS(
        SELECT
            p.group_id,
            SUM(s.sku_retail_price - s.sku_purchase_price) / SUM(s.sku_retail_price) AS max_discount
        FROM
            products p
            JOIN stores s ON p.sku_id = s.sku_id
        GROUP BY
            p.group_id
    ),
	groups AS 	
	(SELECT vg.customer_id,
			vg.group_id,
			(ceil(group_minimum_discount/0.05)*0.05 * 100)::INT AS ceil_minimum_discount,
			ROW_NUMBER() OVER (PARTITION BY vg.customer_id ORDER BY group_affinity_index DESC) AS max_affinity_index
	FROM v_groups vg
	JOIN max_discount md ON vg.group_id = md.group_id	
	WHERE (ceil(group_minimum_discount/0.05)*0.05 * 100)::INT < md.max_discount * margin_share 							
		AND (group_discount_share * 100)::int < max_share_transactions_with_discount 
		AND group_churn_rate <= max_churn_index
	ORDER BY 1, 2)
	SELECT g.customer_id,
			first_date AS start_date,
			last_date AS end_date, 
			(round((EXTRACT (EPOCH FROM (last_date - first_date))/86400) / customer_frequency)::INT + number_transactions) AS required_transactions_count,
			pg.group_name,
			g.ceil_minimum_discount AS offer_discount_depth
	FROM groups g
	JOIN v_customers vc ON g.customer_id = vc.customer_id	
	JOIN product_groups pg ON g.group_id = pg.group_id
	WHERE max_affinity_index = 1
	ORDER BY 1;
END;				
$$ LANGUAGE PLPGSQL;
