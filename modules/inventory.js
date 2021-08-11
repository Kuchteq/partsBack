const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const withPaginSort = require('../functions/pagination');
const checkStock = require('../functions/stockChecker');

router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'Part added';

const partsAddSchema = yup.object().shape({
  part_name: yup.string().required(),
  stock: yup.number().integer().required(),
  price: yup.number().integer().required(),
  purchase_date: yup.date().required(),
  short_note: yup.string(),
  supplier_id: yup.number().required(),
  segment_id: yup.number().integer().required(),
});

router.get('/inventory', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  //short for query string
  const QS = withPaginSort(
    `SELECT parts.id as part_id, parts.name as part_name, parts.stock, parts.price, parts.purchase_date, parts.short_note,
  suppliers.name as suppliers_name, segments.name as segments_name FROM parts 
  JOIN suppliers ON (parts.supplier_id = suppliers.id) 
  JOIN segments ON (parts.segment_id = segments.id)`,
    req.query.page,
    req.query.sort_by,
    req.query.sort_dir
  );

  pool.query(QS, async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/inventory/:id', async (req, res) => {
  'Here express will pull id individual data from the database and return it in this form';

  const QS = `SELECT parts.id as part_id, parts.name as part_name, parts.stock, parts.price, parts.purchase_date, parts.short_note,
  suppliers.name as suppliers_name, segments.name as segments_name FROM parts 
  JOIN suppliers ON (parts.supplier_id = suppliers.id) 
  JOIN segments ON (parts.segment_id = segments.id) WHERE parts.id = $1`;

  pool.query(QS, [req.params.id], async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.post('/inventory/', async (req, res) => {
  'Here all the arguments like segment, model name, amount, price will be passed';

  const QS = `INSERT INTO parts (name, stock, price, purchase_date, short_note,
      supplier_id, segment_id) VALUES ($1, $2, $3, $4, $5, $6, $7)`;

  try {
    await partsAddSchema.validate(req.body);
    pool.query(QS, Object.values(req.body), (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);
        res.status(406).send(bodyErrror);
      } else {
        res.status(200).send(insertSuccess);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

router.put('/inventory/', async (req, res) => {
  'Here all the arguments like segment, model name, amount, price will be passed';

  const QS = `UPDATE parts SET name = $1, stock = $2, price = $3, purchase_date = $4, short_note = $5,
      supplier_id = $6, segment_id = $7 WHERE id = $8`;

  try {
    await partsAddSchema.validate(req.body);
    pool.query(QS, Object.values(req.body), (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);
        res.status(406).send(bodyErrror);
      } else {
        res.status(200).send(insertSuccess);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

router.post('/inventory-sell/', async (req, res) => {
  'In the options the individual ids of parts will be passed for the backend to delete;';
  const chunks = req.body.chunks;
  const newOrderQS = 'INSERT INTO orders (client_id, sell_date) VALUES ($1, $2) RETURNING id;';
  const createChunkQS = 'INSERT INTO order_chunks (part_id, sell_price, quantity, belonging_order_id) VALUES ($1, $2, $3, $4);';

  const subtractStockQS = 'UPDATE parts SET stock = stock - $1 WHERE id = $2';

  checkStock(chunks)
    .then(() =>
      pool.query(newOrderQS, [req.body.client_id, req.body.sell_date], (err, q2Results) => {
        if (!err) {
          const newOrderId = q2Results.rows[0].id;
          chunks.map(chunk => {
            pool.query(createChunkQS, [chunk.part_id, chunk.sell_price, chunk.quantity, newOrderId]).catch(err => console.log(err));
            //subtract approriate amount from stock
            pool.query(subtractStockQS, [chunk.quantity, chunk.part_id]);
          });
          res.status(200).send('Order created');
        } else {
          console.log('SQL problem ' + err);
          res.status(406).send(bodyErrror);
        }
      })
    )
    .catch(err => {
      res.status(406).send(err);
    });
});

module.exports = router;
