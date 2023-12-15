--@block
--@label v_customers
SELECT * FROM v_customers;

--@block
--@label v_purchase_history
SELECT * FROM v_purchase_history;

--@block
--@label v_periods
SELECT * FROM v_periods;

--@block
--@label v_groups
SELECT * FROM v_groups;

--@block
--@label part5
SELECT *
FROM personal_offers_visits('2022-08-18 00:00:00', '2022-08-18 00:00:00', 1, 3, 70, 30);

--@block
--@label part6
SELECT * FROM margin_growth(5, 3, 0.5, 100, 30);
