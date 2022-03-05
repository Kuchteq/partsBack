//Importing the necessary libraries/tools
const express = require('express');
const yup = require('yup');
const pool = require('../db');
const { withParams } = require('../functions/withParams');
const registerEvent = require('../functions/registerEvent');

/*This is the router for the inventory module, it is similar to the app object in the back.js
 where it too can have its routes and middleware defined but its purpose in the end is to be
 appended to this main file with all the other router objects defined in other files*/
const router = express.Router();
router.use(express.json());

const BODY_ERROR = "There's something wrong with data body, see console errors";
const INSERT_SUCCESS = 'Part added';

/* defining schema allows for verifying whether the request made 
to the server follows the expected form */
const PARTS_ADD_SCHEMA = yup.object().shape({
  segment_id: yup.number().integer().required(),
  part_name: yup.string().required(),
  stock: yup.number().integer().required(),
  price: yup.number().required(),
  supplier_id: yup.number().required(),
  short_note: yup.string().nullable(),
  purchase_date: yup.date().required(),
});

router.get('/inventory', async (req, res) => {
  //This route controller is for getting the list of 20 parts from the database

  /* short for query string, this is the query asked to the database, the with params function
   is to modify the query and add sorting and filtering functionality and restrict the amount of asked records*/
  req.query.sort_by = req.query.sort_by == 'segment_id' ? 'segments.name': req.query.sort_by; 
  let conditions = req.query.past == 'true' ? undefined : 'parts.stock > 0'
  const QS = withParams(
    `SELECT parts.id as part_id, segments.name as segments_name, parts.name as part_name, parts.stock, 
    trim_scale(parts.price) as price, parts.short_note, suppliers.name as suppliers_name, parts.suggested_price as suggested_price,
    TO_CHAR(parts.purchase_date :: DATE, 'dd/mm/yyyy') AS purchase_date FROM parts 
    LEFT JOIN suppliers ON (parts.supplier_id = suppliers.id) LEFT JOIN segments ON (parts.segment_id = segments.id) `,
    req.query.page, req.query.sort_by, req.query.sort_dir, req.query.s, ['parts'], conditions
  );
  //pool is the connection to the database, QS is the query string, values is the values to be inserted to the query
  pool.query(QS, async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(BODY_ERROR);
    } else {
      //if everything is all right with the query, the results are sent to the client
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/inventory/:id', async (req, res) => {
  //This route controller is for getting retrieving information on a single part from the database based on its id

  //short for query string, this is the query asked to the database
  const QS = `SELECT segments.id as segment_id, parts.name as part_name, parts.stock as stock, parts.price, 
  parts.short_note, purchase_date, jsonb_build_object('value', suppliers.id, 'label', suppliers.name) as supplier_obj, 
  parts.suggested_price as suggested_price, jsonb_build_object('value', segments.id, 'label', segments.name) as segment_obj, 
  parts.id as part_id FROM parts LEFT JOIN suppliers ON (parts.supplier_id = suppliers.id) 
    LEFT JOIN segments ON (parts.segment_id = segments.id) WHERE parts.id = $1;`;

  pool.query(QS, [req.params.id], async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(BODY_ERROR);
    } else {
      res.status(200).send(qResults.rows[0]);
    }
  });
});

router.post('/inventory', async (req, res) => {
  //This route controller is for adding a new part to the database

  const QS = `INSERT INTO parts (segment_id, name, stock, price, supplier_id, short_note, suggested_price, purchase_date)
   VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id;`;

  try {
    await PARTS_ADD_SCHEMA.validate(req.body);
    pool.query(QS, Object.values(req.body), (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);

        res.status(406).send(BODY_ERROR);
      } else {
        registerEvent(0, qResults.rows[0].id, req.body.part_name); // add the newly created item/person to the history
        res.status(200).send(INSERT_SUCCESS);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(BODY_ERROR);
  }
});

router.put('/inventory/:id', async (req, res) => {
  //This route controller is for updating a part in the database

  const QS = `UPDATE parts SET segment_id = $1, name = $2, stock = $3, price = $4, supplier_id = $5,
  short_note = $6, suggested_price = $7, purchase_date = $8 WHERE id = $9 RETURNING id`;

  try {
    await PARTS_ADD_SCHEMA.validate(req.body);
    pool.query(QS, [...Object.values(req.body), req.params.id], (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);
        res.status(406).send(BODY_ERROR);
      } else {
        registerEvent(1, qResults.rows[0].id, req.body.name); // add an entry to the history stating the update
        res.status(200).send(INSERT_SUCCESS);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(BODY_ERROR);
  }
});

router.delete('/inventory/:id', async (req, res) => {
  //This route controller is for deleting a part from the database

  const itemToDeleteId = req.params.id;
  const QS = `DELETE FROM parts WHERE id = $1 RETURNING name`;

  pool.query(QS, [itemToDeleteId], async (err, qResults) => {
    if (err || qResults.rowCount < 1) {
      console.log('unsucessful delete ' + err);
      res.status(400).send(BODY_ERROR);
    } else {
      registerEvent(2, itemToDeleteId, qResults.rows[0].name);
      res.status(200).send('Successfuly deleted part');
    }
  });
});

router.get('/inventory-basic/:arr', async (req, res) => {
  //controller for getting the basic information of a part from the database based on a list of ids 

  const QS = `SELECT parts.id as part_id, jsonb_build_object('value', segments.id, 'label', segments.name) as segment_obj, 
  parts.name as part_name, parts.stock, parts.price FROM parts LEFT JOIN segments on 
  (parts.segment_id = segments.id) WHERE parts.id IN(${req.params.arr})`;

  pool.query(QS, [], async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(BODY_ERROR);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/inventory-all-bycat/:cat', async (req, res) => {
  //controller for getting the basic information on all the parts from the database based on their category

  const QS = `SELECT parts.id as value, parts.name as label, parts.stock, parts.price 
  FROM parts WHERE segment_id = $1 AND parts.stock > 0 ORDER BY id DESC`;

  pool.query(QS, [req.params.cat], async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(BODY_ERROR);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});
router.get('/segment-list', async (req, res) => {
  //controller for getting the list of segments from the database

  pool.query('SELECT id as value, name as label FROM segments ORDER by id', async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(BODY_ERROR);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

//exporting this object so that it can be imported in the main back.js
module.exports = router;
