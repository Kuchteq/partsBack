const express = require('express');
const router = express.Router();
const pool = require('../db');
const withParams = require('../functions/pagination');

router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";

router.get('/history', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  //short for query string
  const QS = withParams(
    `SELECT history.id as history_id, action_types.type_name as prefix, history.details as details, TO_CHAR(at_time :: DATE, 'dd/mm/yyyy hh:mm') as at_time FROM history 
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
