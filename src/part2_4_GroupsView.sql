--@block
---Функция, возвращающая таблицу с расчетом фактической маржи по группе для клиента---
CREATE OR REPLACE FUNCTION customer_margin(
    IN method VARCHAR DEFAULT 'default',
    IN parameter INT DEFAULT 1e+6
)
    RETURNS TABLE(
            customer_id BIGINT,
            group_id INT,
            group_margin NUMERIC
        )
        AS $$
BEGIN
    IF method = 'default' THEN
        RETURN QUERY
        SELECT
            vph.customer_id,
            vph.group_id,
            SUM(vph.group_summ_paid - vph.group_cost) AS group_margin
        FROM
            v_purchase_history vph
        GROUP BY
            vph.customer_id, vph.group_id;
    ELSIF method = 'period' THEN
        RETURN QUERY
        SELECT
            vph.customer_id,
            vph.group_id,
            SUM(vph.group_summ_paid - vph.group_cost) AS group_margin
        FROM
            v_purchase_history vph
        WHERE
            vph.transaction_datetime >= analyzed_period() - interval '1 day' * parameter
        GROUP BY
            vph.customer_id, vph.group_id;
    ELSIF method = 'transactions' THEN
        RETURN QUERY
        SELECT
            b.customer_id,
            b.group_id,
            SUM(b.group_summ_paid - b.group_cost) AS margin
        FROM(
            SELECT
                vph.customer_id,
                vph.group_id,
                vph.group_summ_paid,
                vph.group_cost,
                ROW_NUMBER() OVER(PARTITION BY vph.customer_id, vph.group_id ORDER BY vph.transaction_datetime DESC) AS rn
            FROM
                v_purchase_history vph) AS b
    WHERE
        b.rn <= parameter
    GROUP BY
        b.customer_id, b.group_id;
    END IF;
END;
$$
LANGUAGE PLPGSQL;

--@block
CREATE OR REPLACE VIEW v_groups AS
WITH purchases AS (
    SELECT
        vph.customer_id,
        vph.group_id,
        vph.transaction_id,
        vph.transaction_datetime,
        vph.group_summ,
        vph.group_summ_paid,
        SUM(ch.sku_discount) AS sku_discount,
        EXTRACT(EPOCH FROM (vph.transaction_datetime - LAG(vph.transaction_datetime, 1) OVER (PARTITION BY vph.customer_id, vph.group_id ORDER BY vph.transaction_datetime))) / 86400 AS interval
    FROM
        v_purchase_history vph
        LEFT JOIN products p ON vph.group_id = p.group_id
        LEFT JOIN checks ch ON vph.transaction_id = ch.transaction_id
            AND p.sku_id = ch.sku_id
    GROUP BY
        vph.customer_id, vph.group_id, vph.transaction_id, vph.transaction_datetime, vph.group_summ, vph.group_summ_paid
),
affinity_transactions AS (
    SELECT
        pu.customer_id,
        pe.group_id,
        COUNT(DISTINCT pu.transaction_id) AS tr_total
    FROM
        purchases pu
        JOIN v_periods pe ON pu.customer_id = pe.customer_id
    WHERE
        pu.transaction_datetime BETWEEN pe.first_group_purchase_date AND pe.last_group_purchase_date
    GROUP BY
        pu.customer_id, pe.group_id
),
stability_idx AS (
    SELECT
        p.customer_id,
        p.group_id,
        CASE WHEN MAX(vp.group_frequency) IS NOT NULL THEN
            COALESCE(AVG(ABS(p.interval - vp.group_frequency) / vp.group_frequency), 1)
        END AS group_stability_index
    FROM
        purchases p
        JOIN v_periods vp ON p.customer_id = vp.customer_id
            AND p.group_id = vp.group_id
    GROUP BY
        p.customer_id, p.group_id
),
discounts AS (
    SELECT
        customer_id,
        group_id,
        COUNT(DISTINCT transaction_id) AS tr_total,
        CASE WHEN SUM(group_summ) = 0 THEN
            NULL
        ELSE
            SUM(group_summ_paid) / SUM(group_summ)
        END AS group_average_discount
    FROM
        purchases
    WHERE
        sku_discount > 0
    GROUP BY
        customer_id, group_id
)
SELECT
    p.customer_id,
    p.group_id,
    p.group_purchase::NUMERIC / af.tr_total AS group_affinity_index,
    EXTRACT(epoch FROM analyzed_period() - p.last_group_purchase_date) / 86400 / p.group_frequency AS group_churn_rate,
    group_stability_index AS group_stability_index,
    cm.group_margin,
    CASE WHEN p.group_purchase = 0 THEN
        NULL
    ELSE
        COALESCE(d.tr_total, 0)::NUMERIC / p.group_purchase
    END AS group_discount_share,
    CASE WHEN p.group_min_discount > 0 THEN
        p.group_min_discount
    END AS group_minimum_discount,
    d.group_average_discount
FROM
    v_periods p
    LEFT JOIN affinity_transactions af ON p.customer_id = af.customer_id
        AND p.group_id = af.group_id
    LEFT JOIN stability_idx st ON p.customer_id = st.customer_id
        AND p.group_id = st.group_id
    LEFT JOIN customer_margin() cm ON p.customer_id = cm.customer_id
        AND p.group_id = cm.group_id
    LEFT JOIN discounts d ON p.customer_id = d.customer_id
        AND p.group_id = d.group_id
ORDER BY
    customer_id,
    group_id;
