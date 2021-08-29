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

router.get('/supplier-list', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  pool.query('SELECT id as value, name as label FROM suppliers ORDER by join_date', async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/client-list', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  pool.query('SELECT id as value, name as label FROM clients ORDER by join_date', async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});
module.exports = router;
