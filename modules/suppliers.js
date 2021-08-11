const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const withPaginSort = require('../functions/pagination');

router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'Supplier added';

const suppliersSchema = yup.object().shape({
  supplier_name: yup.string().required(),
  join_date: yup.date().required(),
  website: yup.string().url(),
  email: yup.string().email(),
  phone: yup.string(),
  adress: yup.string(),
  nip: yup.string().length(10),
  short_note: yup.string(),
});

router.get('/suppliers', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  //short for query string

  const insideQS = `SELECT DISTINCT ON (suppliers.id) suppliers.id as supplier_id, suppliers.name as supplier_name, join_date, website, email, phone, adress, nip, suppliers.short_note as supplier_short_note, parts.name as last_purchased_part FROM suppliers LEFT JOIN parts ON suppliers.id = parts.supplier_id ORDER BY suppliers.id, parts.purchase_date DESC`;

  const wholeQS = withPaginSort(
    `WITH distinctSuppliers AS (${insideQS}) SELECT supplier_id, supplier_name, join_date, website, email, phone, adress, nip, supplier_short_note, last_purchased_part FROM distinctSuppliers`,
    req.query.page,
    req.query.sort_by,
    req.query.sort_dir
  );
  console.log(wholeQS);
  pool.query(wholeQS, async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/suppliers/:id', async (req, res) => {
  'Here express will pull id individual data from the database and return it in this form';

  const QS = `SELECT id, name, join_date, website, email, phone, adress, nip, short_note FROM suppliers WHERE id = $1`;

  pool.query(QS, [req.params.id], async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.post('/suppliers/', async (req, res) => {
  'Here all the arguments like segment, model name, amount, price will be passed';

  const QS = `INSERT INTO suppliers (name, join_date, website, email, phone,
      adress, nip, short_note) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`;

  try {
    await suppliersSchema.validate(req.body);
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

router.put('/suppliers/', async (req, res) => {
  'Here all the arguments like segment, model name, amount, price will be passed';

  const QS = `UPDATE suppliers SET name = $1, join_date = $2, website = $3, email = $4, phone = $5,
        adress = $6, nip = $7, short_note = $8 WHERE id = $9`;

  try {
    await suppliersSchema.validate(req.body);
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

module.exports = router;
