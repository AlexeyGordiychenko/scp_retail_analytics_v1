-- @block
CREATE OR REPLACE FUNCTION margin_growth(
    groups_number INT,
    max_churn_idx NUMERIC,
    max_stability_idx NUMERIC,
    max_sku_share NUMERIC,
    magin_share NUMERIC
)
    RETURNS TABLE(
            customer_id INT,
            sku_name VARCHAR,
            offer_discount_depth NUMERIC
        )
        AS $$
    WITH margin_groups AS(
        SELECT
            customer_id,
            group_id,
            min_discount
        FROM(
            SELECT
                customer_id,
                group_id,
                CEIL(group_minimum_discount * 100 / 5) * 5 AS min_discount,
                ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY group_affinity_index DESC) AS rn
            FROM
                v_groups
            WHERE
                group_churn_rate <= max_churn_idx
                AND group_stability_index < max_stability_idx) AS t
        WHERE
            t.rn <= groups_number
    ),
    sku_max_margin AS(
        SELECT
            customer_id,
            group_id,
            sku_id,
            sku_margin,
            sku_retail_price,
            min_discount
        FROM(
            SELECT
                mg.customer_id,
                mg.group_id,
                s.sku_id,
                s.sku_retail_price - s.sku_purchase_price AS sku_margin,
                s.sku_retail_price,
                mg.min_discount,
                ROW_NUMBER() OVER(PARTITION BY mg.customer_id,
                    mg.group_id ORDER BY s.sku_retail_price - s.sku_purchase_price DESC) AS rn
            FROM
                margin_groups mg
                JOIN products p ON mg.group_id = p.group_id
                JOIN main_store() ms ON mg.customer_id = ms.customer_id
                JOIN stores s ON ms.main_store = s.transaction_store_id
                    AND p.sku_id = s.sku_id) AS d
        WHERE
            rn = 1
    ),
    sku_share AS(
        SELECT
            customer_id,
            group_id,
            sku_id,
            tr / SUM(tr) OVER(PARTITION BY customer_id,
                group_id) AS sku_share
        FROM(
            SELECT
                smm.customer_id,
                smm.group_id,
                smm.sku_id,
                COUNT(DISTINCT ct.transaction_id) AS tr
            FROM
                sku_max_margin smm
                JOIN customer_transactions() ct ON smm.customer_id = ct.customer_id
                JOIN checks ch ON ct.transaction_id = ch.transaction_id
                    AND smm.sku_id = ch.sku_id
            GROUP BY
                smm.customer_id, smm.group_id, smm.sku_id) AS t
    )
    SELECT
        smm.customer_id,
        p.sku_name,
        smm.min_discount AS offer_discount_depth
    FROM
        sku_max_margin smm
        JOIN sku_share ss ON smm.customer_id = ss.customer_id
            AND smm.group_id = ss.group_id
            AND smm.sku_id = ss.sku_id
            AND ss.sku_share <= max_sku_share / 100
        JOIN products p ON smm.sku_id = p.sku_id
    WHERE
        CASE WHEN smm.sku_retail_price = 0 THEN
            0
        ELSE
            magin_share * smm.sku_margin / smm.sku_retail_price
        END >= smm.min_discount
    ORDER BY
        smm.customer_id,
        p.sku_name,
        smm.min_discount;
$$
LANGUAGE SQL;
