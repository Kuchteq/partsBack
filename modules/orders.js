const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const checkStock = require('../functions/stockChecker');
const checkComputerExistance = require('../functions/computerChecker.js');
const registerEvent = require('../functions/registerEvent');
const { withParams, onlySearch } = require('../functions/withParams');
router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'Part added';

router.get('/orders/:year/:month', (req, res) => {
  const QS = onlySearch(`WITH compinfo AS (SELECT orders.id as id, SUM(parts.price) AS value FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id 
  JOIN computers ON order_chunks.computer_id = computers.id JOIN computer_pieces on computers.id = computer_pieces.belonging_computer_id INNER JOIN parts ON
  computer_pieces.part_id = parts.id WHERE EXTRACT(YEAR FROM orders.sell_date) = $1 AND EXTRACT(MONTH FROM orders.sell_date) = $2 GROUP BY orders.id, computers.name)
SELECT orders.id as order_id, clients.name as client_name, orders.name as order_name,
ARRAY_REMOVE(ARRAY_CAT(ARRAY_AGG(parts.name),ARRAY_AGG(computers.name)),NULL) as parts,  SUM(order_chunks.quantity) as items_amount, 
COALESCE(SUM(parts.price*order_chunks.quantity),0)+COALESCE(SUM(compinfo.value),0) as items_value, 
SUM(order_chunks.sell_price*order_chunks.quantity) - COALESCE(SUM(parts.price*order_chunks.quantity),0)-COALESCE(SUM(compinfo.value),0) as profit,orders.sell_date as sell_date FROM orders  
JOIN order_chunks ON order_chunks.belonging_order_id = orders.id  LEFT JOIN computers on order_chunks.computer_id = computers.id
LEFT JOIN compinfo ON compinfo.id = orders.id JOIN clients ON orders.client_id = clients.id  LEFT JOIN parts ON order_chunks.part_id = parts.id  
WHERE EXTRACT(YEAR FROM orders.sell_date) = $1 AND EXTRACT(MONTH FROM orders.sell_date) = $2 `,
    req.query.s, ['orders', 'parts', 'clients', 'computers'], null, 'AND (',
    `${req.query.s ? ')' : ''} GROUP BY orders.id, clients.name ORDER BY ${req.query.sort_by} ${req.query.sort_dir}`)


  console.log(QS)
  pool.query(QS, [req.params.year, req.params.month], (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/orders-basic/:id', (req, res) => {

  const orderBasicInfo = `SELECT orders.name as name, jsonb_build_object('value', clients.id, 'label', clients.name) as client_obj, sell_date 
  FROM orders JOIN clients ON orders.client_id = clients.id WHERE orders.id = $1`

  pool.query(orderBasicInfo, [req.params.id], (err, q1Results) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      let orderInfo = q1Results.rows[0];
      res.status(200).send(orderInfo);
    }
  });
});

router.get('/orders-chunks/:id', (req, res) => {

  const orderPartChunksQS = `SELECT part_id, order_chunks.sell_price as sold_at,
    order_chunks.quantity as quantity
    FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id 
    WHERE orders.id = $1 AND order_chunks.computer_id IS NULL;`;

  const orderCompChunksQS = `SELECT computer_id, order_chunks.sell_price as sold_at
  FROM orders JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
  WHERE orders.id = $1 AND order_chunks.computer_id IS NOT NULL;`;

  pool.query(orderPartChunksQS, [req.params.id], (err, q1Results) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      let partsInfo = q1Results.rows;
      pool.query(orderCompChunksQS, [req.params.id], (err, q2Results) => {
        if (err) {
          console.log(err);
          res.status(400).send(bodyErrror);
        } else {
          let compsInfo = q2Results.rows;
          res.status(200).send({ partsInfo, compsInfo });
        }
      })
    }
  });
})


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
    }).catch(err => {
      res.status(406).send(err);
    });
});


const returnPartsStock = `UPDATE parts SET stock = parts.stock + order_chunks.quantity
  FROM order_chunks WHERE order_chunks.belonging_order_id IN ($1)`

const deletePartChunk = `DELETE FROM order_chunks WHERE belonging_order_id IN($1)`;
const deleteOrder = `DELETE FROM orders WHERE id IN($1)`;

router.delete('/orders/:id', async (req, res) => {
  let promises = []
  const deleteComputerChunk = req.body.computers && req.body.computers.length > 0 ? `DELETE FROM order_chunks WHERE belonging_order_id IN($1)` : 'SELECT $1';

  const list = [returnPartsStock, deletePartChunk, deleteComputerChunk, deleteOrder]
  list.forEach(query => {
    promises.push(new Promise((resolve, reject) => {
      pool.query(query, [req.params.id]).then(() => {
        resolve();
      })
    }))
  })
  Promise.all(promises).then(data => {
    res.status(200).send('Successfuly deleted part');
  })
})


router.put('/orders/:id', async (req, res) => {
  const parts = req.body.parts;
  const computers = req.body.computers;
  const id = req.params.id;

  const createPartChunkQS = 'INSERT INTO order_chunks (part_id, sell_price, quantity, belonging_order_id) VALUES ($1, $2, $3, $4);';
  const createComputerChunkQS = 'INSERT INTO order_chunks (computer_id, sell_price, quantity, belonging_order_id) VALUES ($1, $2, $3, $4);';
  const subtractPartStockQS = 'UPDATE parts SET stock = stock - $1 WHERE id = $2';

  let computersToCheck = [];
  computers.forEach(computer => {
    computersToCheck.push(computer.computer_id);
  });
  const deleteComputerChunk = computers && computers.length > 0 ? `DELETE FROM order_chunks WHERE belonging_order_id IN($1)` : 'SELECT $1';


  pool.query('BEGIN').then(async () => {
    //sorry for code repetition but the rollback doesn't work with outside functions making the query
    await pool.query(returnPartsStock, [id])
    await pool.query(deletePartChunk, [id])
    await pool.query(deleteComputerChunk, [id])
    for (const chunk of parts) {
      await pool.query(createPartChunkQS, [chunk.part_id, chunk.sell_price, chunk.quantity, id]).catch(err => console.log(err));
      //subtract approriate amount from stock
      await pool.query(subtractPartStockQS, [chunk.quantity, chunk.part_id]);
    }
    for (const chunk of computers) {
      await pool
        .query(createComputerChunkQS, [chunk.computer_id, chunk.sell_price, chunk.quantity, id])
        .catch(err => console.log(err));
    }
    await pool.query('COMMIT')
    await res.send('ok')

  })
})


router.get('/orders-span/:from/:to', async (req, res) => {
  const { from, to } = req.params;
  const QS = withParams(`SELECT  orders.id as order_id, clients.name as client_name, orders.name as order_name,
    ARRAY_AGG(parts.name) as parts,  SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, sum(order_chunks.sell_price - parts.price) as profit,
    orders.sell_date as sell_date FROM orders  JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id  JOIN parts ON order_chunks.part_id = parts.id 
    WHERE orders.sell_date between $1 and $2
    GROUP BY orders.id, clients.name `, req.query.page,
    req.query.sort_by,
    req.query.sort_dir
  );
  pool.query(QS, [from, to], (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
})


router.get('/orders-clients/:client', async (req, res) => {

  const QS = withParams(`SELECT orders.id as order_id, clients.name as client_name, orders.name as order_name,
    ARRAY_AGG(parts.name) as parts,  SUM(order_chunks.quantity) as items_amount, SUM(parts.price) as items_value, sum(order_chunks.sell_price - parts.price) as profit,
    orders.sell_date as sell_date FROM orders  JOIN order_chunks ON order_chunks.belonging_order_id = orders.id
    JOIN clients ON orders.client_id = clients.id  JOIN parts ON order_chunks.part_id = parts.id 
    WHERE clients.id = $1
    GROUP BY orders.id, clients.name `, req.query.page,
    req.query.sort_by,
    req.query.sort_dir
  );
  pool.query(QS, [req.params.client], (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
})

module.exports = router;
