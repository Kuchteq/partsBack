const express = require('express');
const router = express.Router();
const pool = require('../db');
router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'Part added';

router.get('/getraport/:from/:to', async (req, res) => {
  let { from, to } = req.params;
  let fullResponse = {};
  from = from.replaceAll('-', '/');
  to = to.replaceAll('-', '/');
  console.log(from)
  const generalInfo = `
  WITH all_sale_dets AS (SELECT DISTINCT ON (orders.id) SUM(order_chunks.quantity) as items_amount,
  SUM(parts.price) as items_value,
          sum(order_chunks.sell_price - parts.price) as profit
          FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
      JOIN clients ON orders.client_id = clients.id
          JOIN parts ON order_chunks.part_id = parts.id
          JOIN suppliers ON parts.supplier_id = suppliers.id
      WHERE orders.sell_date between $1 and $2
   GROUP BY orders.id, clients.name),
   new_clients AS (SELECT COUNT(*) FROM clients
          WHERE clients.join_date between $1 and $2)
          SELECT SUM(all_sale_dets.profit) as all_profit,
          SUM(all_sale_dets.items_value) as all_value,
          SUM(all_sale_dets.items_amount) as all_parts_amount,
          COUNT(all_sale_dets) as all_orders,
          CAST(SUM(new_clients.count)/10 AS INT) as new_clients_amount
          FROM new_clients, all_sale_dets
  `

  const byMonthInfo = `
SELECT DATE_TRUNC('month', orders.sell_date) as month, SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE orders.sell_date between $1 and $2
    GROUP BY DATE_TRUNC('month', orders.sell_date)
    `
  const byWeekInfo = `
SELECT DATE_TRUNC('week', orders.sell_date), SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE orders.sell_date between $1 and $2
    GROUP BY DATE_TRUNC('week', orders.sell_date)`

  const segmentInfo = `SELECT segments.name as segment_name, SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit,
   CAST(AVG((order_chunks.sell_price/parts.price-1)*100)as decimal(10,2)) as profit_percentage 
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN segments ON parts.segment_id = segments.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE orders.sell_date between $1 and $2
    GROUP BY segments.id`

  const clientsInfo = `
SELECT clients.name, SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit,
  CAST(AVG((order_chunks.sell_price/parts.price-1)*100)as decimal(10,2)) as profit_percentage 
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN segments ON parts.segment_id = segments.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE orders.sell_date between $1 and $2
    GROUP BY clients.id 
`
  const suppliersSalesInfo = `
SELECT suppliers.name, SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, 
	sum(order_chunks.sell_price - parts.price) as profit,
  CAST(AVG((order_chunks.sell_price/parts.price-1)*100)as decimal(10,2)) as profit_percentage 
	FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
	JOIN parts ON order_chunks.part_id = parts.id 
	JOIN segments ON parts.segment_id = segments.id 
	JOIN suppliers ON parts.supplier_id = suppliers.id 
    WHERE orders.sell_date between $1 and $2
    GROUP BY suppliers.id`

  const suppliersBuyInfo = `
  SELECT suppliers.name, SUM(parts.price) as items_value, COUNT(parts) as items_amount
FROM suppliers JOIN parts ON suppliers.id = parts.supplier_id WHERE parts.purchase_date between $1 and $2 GROUP BY suppliers.id`


  try {
    const generalInfoResult = await pool.query(generalInfo, [from, to]);
    fullResponse.generalInfo = generalInfoResult.rows[0];
    const byMonthInfoResult = await pool.query(byMonthInfo, [from, to]);
    fullResponse.byMonthInfo = byMonthInfoResult.rows;
    const byWeekInfoResult = await pool.query(byWeekInfo, [from, to]);
    fullResponse.byWeekInfo = byWeekInfoResult.rows;
    const segmentInfoResult = await pool.query(segmentInfo, [from, to]);
    fullResponse.segmentInfo = segmentInfoResult.rows;
    const clientsInfoResult = await pool.query(clientsInfo, [from, to]);
    fullResponse.clientsInfo = clientsInfoResult.rows;
    const suppliersSalesInfoResult = await pool.query(suppliersSalesInfo, [from, to]);
    fullResponse.suppliersSalesInfo = suppliersSalesInfoResult.rows
    const suppliersBuyInfoResult = await pool.query(suppliersBuyInfo, [from, to]);
    fullResponse.suppliersBuyInfo = suppliersBuyInfoResult.rows
    res.status(200).json(fullResponse);


  }
  catch (err) {
    console.log(err)
  }
});

module.exports = router;
