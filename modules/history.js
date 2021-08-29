const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const withPaginSort = require('../functions/pagination');
const checkStock = require('../functions/stockChecker');
const checkComputerExistance = require('../functions/computerChecker.js');

router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'Part added';

router.get('/history', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  //short for query string
  const QS = withPaginSort(
    `SELECT history.id as history_id, action_types.id as type_id, action_types.type_name as prefix, history.target_id as target_id, history.details as details, at_time FROM history 
    LEFT JOIN action_types on (history.action_id = action_types.id) `,
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

module.exports = router;