//Importing the necessary libraries/tools
const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const withParams = require('../functions/pagination');
const registerEvent = require('../functions/registerEvent');

router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'Part added';

/* defining schema allows for verifying whether the request made 
to the server follows the expected form */
const partsAddSchema = yup.object().shape({
  segment_id: yup.number().integer().required(),
  part_name: yup.string().required(),
  stock: yup.number().integer().required(),
  price: yup.number().required(),
  supplier_id: yup.number().required(),
  short_note: yup.string().nullable(),
  purchase_date: yup.date().required(),
});

router.get('/inventory', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  //short for query string
  const QS = withParams(
    `SELECT parts.id as part_id, segments.name as segments_name, parts.name as part_name, parts.stock, trim_scale(parts.price), parts.short_note,
  suppliers.name as suppliers_name, TO_CHAR(parts.purchase_date :: DATE, 'dd/mm/yyyy') AS purchase_date FROM parts 
  LEFT JOIN suppliers ON (parts.supplier_id = suppliers.id) 
  LEFT JOIN segments ON (parts.segment_id = segments.id)`,
    req.query.page,
    req.query.sort_by,
    req.query.sort_dir,
    req.query.s,
    ['parts']
  );

  pool.query(QS, async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      console.log(qResults.rows.length);
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/inventory/:id', async (req, res) => {
  //Here express will pull id individual data from the database and return it in this form

  const QS = `SELECT segments.id as segment_id, parts.name as part_name, parts.stock as stock, parts.price, 
  parts.short_note, purchase_date, jsonb_build_object('value', suppliers.id, 'label', suppliers.name) as supplier_obj,
  jsonb_build_object('value', segments.id, 'label', segments.name) as segment_obj, parts.id as part_id FROM parts 
    LEFT JOIN suppliers ON (parts.supplier_id = suppliers.id) 
    LEFT JOIN segments ON (parts.segment_id = segments.id) WHERE parts.id = $1;`;

  pool.query(QS, [req.params.id], async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      console.log(qResults.rows[0]);
      res.status(200).send(qResults.rows[0]);
    }
  });
});

router.post('/inventory', async (req, res) => {
  //Here all the arguments like segment, model name, amount, price will be passed

  const QS = `INSERT INTO parts (segment_id, name, stock, price, supplier_id, short_note, purchase_date) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id;`;

  try {
    await partsAddSchema.validate(req.body);
    pool.query(QS, Object.values(req.body), (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);

        res.status(406).send(bodyErrror);
      } else {
        registerEvent(0, qResults.rows[0].id, req.body.part_name); // add the newly created item/person to the history
        res.status(200).send(insertSuccess);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

router.put('/inventory/:id', async (req, res) => {
  //Here all the arguments like segment, model name, amount, price will be passed

  const QS = `UPDATE parts SET segment_id = $1, name = $2, stock = $3, price = $4, supplier_id = $5,
  short_note = $6, purchase_date = $7 WHERE id = $8 RETURNING id`;

  try {
    await partsAddSchema.validate(req.body);
    pool.query(QS, [...Object.values(req.body), req.params.id], (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);
        res.status(406).send(bodyErrror);
      } else {
        registerEvent(1, qResults.rows[0].id, req.body.name); // add the newly created item/person to the history
        res.status(200).send(insertSuccess);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

router.delete('/inventory/:id', async (req, res) => {
  //Here express delete  individual id data from the database
  const itemToDeleteId = req.params.id;
  const QS = `DELETE FROM parts WHERE id = $1 RETURNING name`;

  pool.query(QS, [itemToDeleteId], async (err, qResults) => {
    if (err || qResults.rowCount < 1) {
      console.log('unsucessful delete ' + err);
      res.status(400).send(bodyErrror);
    } else {
      registerEvent(2, itemToDeleteId, qResults.rows[0].name);
      res.status(200).send('Successfuly deleted part');
    }
  });
});

//basic part info
router.get('/inventory-basic/:arr', async (req, res) => {
  const QS = `SELECT parts.id as part_id, jsonb_build_object('value', segments.id, 'label', segments.name) as segment_obj, 
  parts.name as part_name, parts.stock, parts.price FROM parts LEFT JOIN segments on (parts.segment_id = segments.id) WHERE parts.id IN(${req.params.arr})`;

  pool.query(QS, [], async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/inventory-all-bycat/:cat', async (req, res) => {
  const QS = `SELECT parts.id as value, parts.name as label, parts.stock, parts.price FROM parts WHERE segment_id = $1 ORDER BY id DESC`;

  pool.query(QS, [req.params.cat], async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});
router.get('/segment-list', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  pool.query('SELECT id as value, name as label FROM segments ORDER by id', async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});
//exporting this module so that it can be imported in the main back.js
module.exports = router;
