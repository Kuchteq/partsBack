const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const checkStock = require('../functions/stockChecker');
const checkComputerExistance = require('../functions/computerChecker.js');
const registerEvent = require('../functions/registerEvent');
const withParams = require('../functions/pagination');
router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'Part added';

router.get('/orders/:year/:month', (req, res) => {
  const QS = `SELECT DISTINCT ON (orders.id) orders.id as order_id, clients.name as client_name, orders.name as order_name,
    ARRAY_AGG(parts.name) as parts,  SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, sum(order_chunks.sell_price - parts.price) as profit,
    orders.sell_date as sell_date FROM orders  JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id  JOIN parts ON order_chunks.part_id = parts.id 
    WHERE EXTRACT(YEAR FROM orders.sell_date) = $1 AND EXTRACT(MONTH FROM orders.sell_date) = $2
    GROUP BY orders.id, clients.name;`;

  pool.query(QS, [req.params.year, req.params.month], (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/orders/:id', (req, res) => {
  const onlyOrderDetailsQS = `SELECT client_id, clients.name as client_name, sell_date, orders.name as order_name,
    SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, sum(order_chunks.sell_price - parts.price) as profit,
    sum(order_chunks.sell_price) as sold_at
    FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id  JOIN parts ON order_chunks.part_id = parts.id 
    WHERE orders.id = $1
    GROUP BY client_id, client_name, sell_date, order_name`;

  const orderChunksQS = `SELECT part_id, parts.name as part_name, parts.price as part_price, order_chunks.sell_price as sold_at,
    order_chunks.quantity as quantity
    FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id 
    JOIN parts ON order_chunks.part_id = parts.id
    WHERE orders.id = $1;`;

  pool.query(onlyOrderDetailsQS, [req.params.id], (err, q1Results) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      pool.query(orderChunksQS, [req.params.id], (err, q2Results) => {
        if (err) {
          console.log(err);
          res.status(400).send(bodyErrror);
        } else {
          let orderInfo = q1Results.rows[0];
          Object.assign(orderInfo, { orderPieces: q2Results.rows });
          res.status(200).send(orderInfo);
        }
      });
    }
  });
});

router.post('/orders', async (req, res) => {
  'In the options the individual ids of parts will be passed for the backend to delete;';
  const parts = req.body.parts;
  const computers = req.body.computers;

  const newOrderQS = 'INSERT INTO orders (name, client_id, sell_date) VALUES ($1, $2, $3) RETURNING id;';

  const createPartChunkQS = 'INSERT INTO order_chunks (part_id, sell_price, quantity, belonging_order_id) VALUES ($1, $2, $3, $4);';
  const createComputerChunkQS = 'INSERT INTO order_chunks (computer_id, sell_price, quantity, belonging_order_id) VALUES ($1, $2, $3, $4);';
  const subtractPartStockQS = 'UPDATE parts SET stock = stock - $1 WHERE id = $2';

  let computersToCheck = [];

  computers.forEach(computer => {
    computersToCheck.push(computer.computer_id);
  });
  checkStock(parts)
    .then(() =>
      checkComputerExistance(computersToCheck)
        .then(() =>
          pool.query(newOrderQS, [req.body.name, req.body.client_id, req.body.sell_date], (err, q2Results) => {
            if (!err) {
              const newOrderId = q2Results.rows[0].id;
              parts.map(chunk => {
                pool.query(createPartChunkQS, [chunk.part_id, chunk.sell_price, chunk.quantity, newOrderId]).catch(err => console.log(err));
                //subtract approriate amount from stock
                pool.query(subtractPartStockQS, [chunk.quantity, chunk.part_id]);
              });
              computers.map(chunk => {
                pool
                  .query(createComputerChunkQS, [chunk.computer_id, chunk.sell_price, chunk.quantity, newOrderId])
                  .catch(err => console.log(err));
              });
              res.status(200).send('Order created');
              registerEvent(3, newOrderId, req.body.name);
            } else {
              console.log('SQL problem ' + err);
              res.status(406).send(bodyErrror);
            }
          })
        )
        .catch(err => {
          res.status(406).send(err);
        })
    )
    .catch(err => {
      res.status(406).send(err);
    });
});

router.get('/orders-span/:from/:to', async (req, res) => {
  const { from, to } = req.params;

  const QS = withParams(`SELECT DISTINCT ON (orders.id) orders.id as order_id, clients.name as client_name, orders.name as order_name,
    ARRAY_AGG(parts.name) as parts,  SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, sum(order_chunks.sell_price - parts.price) as profit,
    orders.sell_date as sell_date FROM orders  JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id  JOIN parts ON order_chunks.part_id = parts.id 
    WHERE orders.sell_date between $1 and $2
    GROUP BY orders.id, clients.name `, req.query.page,
    req.query.sort_by,
    req.query.sort_dir
  );
  console.log(QS)
  pool.query(QS, [from, to], (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
})
module.exports = router;
