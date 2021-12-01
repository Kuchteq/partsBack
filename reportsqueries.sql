WITH all_sale_dets AS (SELECT DISTINCT ON (orders.id) SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE EXTRACT(YEAR FROM orders.sell_date) = '2021' AND EXTRACT(MONTH FROM orders.sell_date) = '10'
    GROUP BY orders.id, clients.name),
 new_clients AS (SELECT COUNT(*) FROM clients 
	WHERE EXTRACT(YEAR FROM clients.join_date) = '2021' AND EXTRACT(MONTH FROM clients.join_date) = '9')
	SELECT SUM(all_sale_dets.profit) as all_profit, 
	SUM(all_sale_dets.items_value) as all_value,
	SUM(all_sale_dets.items_amount) as all_parts_amount,
	COUNT(all_sale_dets) as all_orders,
	CAST(SUM(new_clients.count)/10 AS INT) as new_clients_amount
	FROM new_clients, all_sale_dets

'For raporting every segment'
const saltRounds = 10;
SELECT segments.name as segment_name, SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN segments ON parts.segment_id = segments.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE EXTRACT(YEAR FROM orders.sell_date) = '2021' AND EXTRACT(MONTH FROM orders.sell_date) = '10'
    GROUP BY segments.name

'For raporting individual days' 

SELECT DATE_TRUNC('day', orders.sell_date), SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE EXTRACT(YEAR FROM orders.sell_date) = '2021' AND EXTRACT(MONTH FROM orders.sell_date) = '10'
    GROUP BY DATE_TRUNC('day', orders.sell_date)

'For raporting individual months'
	
	SELECT DATE_TRUNC('month', orders.sell_date), SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE EXTRACT(YEAR FROM orders.sell_date) = '2021' AND EXTRACT(MONTH FROM orders.sell_date) IN ('10', '9','8')
    GROUP BY DATE_TRUNC('month', orders.sell_date)

'For raporting individual clients'

SELECT clients.name, SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN segments ON parts.segment_id = segments.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE orders.sell_date between $1 and $2
    GROUP BY clients.name 
	
	

SELECT suppliers.name, SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN segments ON parts.segment_id = segments.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE orders.sell_date between $1 and $2
    GROUP BY suppliers.id 