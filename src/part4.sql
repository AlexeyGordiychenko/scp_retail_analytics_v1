-- Function that determines offers that aimed at the growth of the average check
CREATE OR REPLACE FUNCTION average_check_offers (
    method INT,
    first_date DATE,
    last_date DATE,
    transactions_amount INT,
    avg_check_coefficient NUMERIC,
    max_churn_index NUMERIC,
    max_discount_share NUMERIC,
    margin_share NUMERIC
) 
RETURNS TABLE (
    customer_id INT,
    required_check_measure NUMERIC,
    group_name VARCHAR,
    offer_discount_depth NUMERIC
) 
LANGUAGE PLPGSQL
AS $$
BEGIN
    RETURN QUERY
    SELECT
        id,
        avg_summ,
        sku,
        discount
    FROM (
        WITH purchases AS (
            SELECT
                SUM(group_summ_paid - group_cost) / SUM(group_summ_paid) * margin_share AS discount_depth,
                v_purchase_history.customer_id,
                v_purchase_history.group_id
            FROM
                v_purchase_history
            GROUP BY
                v_purchase_history.customer_id,
                v_purchase_history.group_id
        ),
        transactions_data AS (
            SELECT
                cards.customer_id AS id,
                transactions.transaction_summ AS summ,
                COALESCE(
                    ROW_NUMBER() OVER (
                        PARTITION BY cards.customer_id
                        ORDER BY transactions.transaction_datetime DESC
                    )
                ) AS transactions_count,
                product_groups.group_name AS sku,
                v_groups.group_affinity_index AS affinity_idx,
                v_groups.group_minimum_discount AS min_discount,
                discount_depth
            FROM
                transactions
                INNER JOIN cards ON cards.customer_card_id = transactions.customer_card_id
                INNER JOIN v_groups ON v_groups.customer_id = cards.customer_id
                INNER JOIN product_groups ON product_groups.group_id = v_groups.group_id
                INNER JOIN purchases ON purchases.customer_id = cards.customer_id
                AND purchases.group_id = v_groups.group_id
            WHERE
                v_groups.group_discount_share < max_discount_share / 100
                AND v_groups.group_churn_rate <= max_churn_index
                AND ((method = 1 AND transactions.transaction_datetime BETWEEN first_date AND last_date) OR method = 2)
        )
        SELECT DISTINCT ON (id)
            id,
            AVG(summ) OVER (PARTITION BY id) * avg_check_coefficient AS avg_summ,
            sku,
            affinity_idx,
            CEIL(min_discount * 20) * 5 AS discount
        FROM (
            SELECT
                id,
                summ,
                sku,
                affinity_idx,
                MAX(affinity_idx) OVER (PARTITION BY id) AS max_affinity_idx,
                min_discount,
                discount_depth
            FROM
                transactions_data
            WHERE method = 1 OR (method = 2 AND transactions_count <= transactions_amount)
        ) AS t
        WHERE
            CEIL(min_discount * 20) * 5 < discount_depth
        ORDER BY
            id, affinity_idx DESC
    ) AS t;
END; $$;