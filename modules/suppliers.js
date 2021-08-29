const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const withPaginSort = require('../functions/pagination');
const registerEvent = require('../functions/registerEvent');

router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'Supplier added';

const suppliersSchema = yup.object().shape({
  supplier_name: yup.string().required(),
  phone: yup.string().nullable(),
  email: yup.string().email().nullable(),
  website: yup.string().nullable(),
  adress: yup.string().nullable(),
  nip: yup.string().length(10).nullable(),
  short_note: yup.string().nullable(),
  join_date: yup.date().required(),
});

router.get('/suppliers', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  //short for query string

  const insideQS = `SELECT DISTINCT ON (suppliers.id) suppliers.id as supplier_id, suppliers.name as supplier_name, TO_CHAR(join_date :: DATE, 'dd/mm/yyyy') as join_date, website, email, phone, adress, nip, suppliers.short_note as supplier_short_note, parts.name as last_purchased_part, TO_CHAR(parts.purchase_date :: DATE, 'dd/mm/yyyy') as last_sold_date FROM suppliers LEFT JOIN parts ON suppliers.id = parts.supplier_id
   ORDER BY suppliers.id, parts.purchase_date DESC`;

  const wholeQS = withPaginSort(
    `WITH distinctSuppliers AS (${insideQS}) SELECT supplier_id, supplier_name, join_date, website, phone, email, adress, nip, supplier_short_note, last_purchased_part, TO_CHAR(last_sold_date :: DATE, 'dd/mm/yyyy') as last_sold_date FROM distinctSuppliers`,
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

router.post('/suppliers', async (req, res) => {
  'Here all the arguments like segment, model name, amount, price will be passed';

  const QS = `INSERT INTO suppliers (name, phone, email, website,
    adress, nip, short_note, join_date) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`;

  try {
    await suppliersSchema.validate(req.body);
    pool.query(QS, Object.values(req.body), (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);
        res.status(406).send(bodyErrror);
      } else {
        registerEvent(15, qResults.rows[0].id, req.body.supplier_name); // add the newly created item/person to the history
        res.status(200).send(insertSuccess);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

router.put('/suppliers/:id', async (req, res) => {
  'Here all the arguments like segment, model name, amount, price will be passed';

  const QS = `UPDATE suppliers SET name = $1, join_date = $2, website = $3, email = $4, phone = $5,
        adress = $6, nip = $7, short_note = $8 WHERE id = $9`;

  try {
    await suppliersSchema.validate(req.body);
    pool.query(QS, [...Object.values(req.body), req.params.id], (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);
        res.status(406).send(bodyErrror);
      } else {
        registerEvent(16, req.params.id, req.body.supplier_name); // add the newly created item/person to the history
        res.status(200).send(insertSuccess);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

module.exports = router;
