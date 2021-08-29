const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const withPaginSort = require('../functions/pagination');
const registerEvent = require('../functions/registerEvent');

router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'client added';

const clientsSchema = yup.object().shape({
  client_name: yup.string().required(),
  phone: yup.string().nullable(),
  email: yup.string().email().nullable(),
  adress: yup.string().nullable(),
  nip: yup.string().length(10).nullable(),
  short_note: yup.string().nullable(),
  join_date: yup.date().required(),
});

router.get('/clients', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  //short for query string

  const insideQS = `SELECT DISTINCT ON (clients.id) clients.id as client_id, clients.name as client_name, join_date, email, phone, 
  adress, nip, clients.short_note as client_short_note, parts.name as last_purchased_part, 
  orders.sell_date as last_sold_date FROM clients
  LEFT JOIN orders ON orders.id = clients.id
  LEFT JOIN order_chunks ON order_chunks.id = orders.client_id
  LEFT JOIN parts ON parts.id = order_chunks.part_id  
  ORDER BY clients.id, orders.sell_date DESC`;

  const wholeQS = withPaginSort(
    `WITH distinctClients AS (${insideQS}) SELECT client_id, client_name, TO_CHAR(join_date :: DATE, 'dd/mm/yyyy') as join_date, phone, email, adress, nip, client_short_note, last_purchased_part, TO_CHAR(last_sold_date :: DATE, 'dd/mm/yyyy') as last_sold_date FROM distinctClients`,
    req.query.page,
    req.query.sort_by,
    req.query.sort_dir
  );

  pool.query(wholeQS, async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/clients/:id', async (req, res) => {
  'Here express will pull id individual data from the database and return it in this form';

  const QS = `SELECT id, name, join_date, website, email, phone, adress, nip, short_note FROM clients WHERE id = $1`;

  pool.query(QS, [req.params.id], async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.post('/clients/', async (req, res) => {
  'Here all the arguments like segment, model name, amount, price will be passed';

  const QS = `INSERT INTO clients (name, phone, email,
      adress, nip, short_note, join_date) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`;
  console.log(req.body);
  try {
    await clientsSchema.validate(req.body);
    pool.query(QS, Object.values(req.body), (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);
        res.status(406).send(bodyErrror);
      } else {
        registerEvent(12, qResults.rows[0].id, req.body.client_name); // add the newly created item/person to the history
        res.status(200).send(insertSuccess);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

router.put('/clients/:id', async (req, res) => {
  'Here all the arguments like segment, model name, amount, price will be passed';

  const QS = `UPDATE clients SET name = $1, join_date = $2, website = $3, email = $4, phone = $5,
        adress = $6, nip = $7, short_note = $8 WHERE id = $9`;

  try {
    await clientsSchema.validate(req.body);
    pool.query(QS, [...Object.values(req.body), req.params.id], (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);
        res.status(406).send(bodyErrror);
      } else {
        registerEvent(13, req.params.id, req.body.client_name);
        res.status(200).send(insertSuccess);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

module.exports = router;
