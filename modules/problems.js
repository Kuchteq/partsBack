const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const withPaginSort = require('../functions/pagination');
const checkStock = require('../functions/stockChecker');
const checkComputerExistance = require('../functions/computerChecker.js');
const registerEvent = require('../functions/registerEvent');

router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'Problem added';
const updateSuccess = 'Problem updated';

const problemsAddSchema = yup.object().shape({
  computer_id: yup.number().required(),
  problem_note: yup.string().required(),
  hand_in_date: yup.date(),
  deadline_date: yup.date(),
});

router.get('/problems', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  //short for query string
  const QS = withPaginSort(
    `SELECT computers.name as computer_name, problems.id, computer_id, problem_note, hand_in_date, deadline_date, finished
      FROM problems JOIN computers ON (computer_id = computers.id) `,
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

router.post('/problems', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  //short for query string
  const QS = 'INSERT INTO problems (computer_id, problem_note, hand_in_date, deadline_date) VALUES ($1, $2, $3, $4) RETURNING id';
  try {
    await problemsAddSchema.validate(req.body);
    checkComputerExistance([req.body.computer_id])
      .then(() =>
        pool.query(QS, Object.values(req.body), (err, qResults) => {
          if (err) {
            res.status(400).send(bodyErrror);
          } else {
            registerEvent(8, qResults.rows[0].id, req.body.problem_note);
            res.status(200).send(insertSuccess);
          }
        })
      )
      .catch(err => {
        res.status(406).send(err);
      });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

router.put('/problems/:id', async (req, res) => {
  'Here all the arguments like segment, model name, amount, price will be passed';

  const QS = 'UPDATE problems SET computer_id = $1, problem_note = $2, hand_in_date = $3, deadline_date = $4 WHERE id = $5';

  try {
    await problemsAddSchema.validate(req.body);
    pool.query(QS, [...Object.values(req.body), req.params.id], (err, qResults) => {
      if (err) {
        console.log('SQL problem ' + err);
        res.status(406).send(bodyErrror);
      } else {
        registerEvent(9, req.params.id, req.body.problem_note);
        res.status(200).send(updateSuccess);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

router.post('/problems-finish/:id', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  const computer_id = req.params.id;
  //short for query string
  const QS = 'UPDATE problems SET finished = $1 WHERE id = $2 RETURNING problem_note';

  try {
    pool.query(QS, [req.body.finished, computer_id], (err, qResults) => {
      if (err) {
        res.status(400).send(bodyErrror);
      } else {
        registerEvent(10, req.params.id, qResults.rows[0].problem_note);
        res.status(200).send(updateSuccess);
      }
    });
  } catch (err) {
    console.log('Data validation problem ' + err);
    res.status(406).send(bodyErrror);
  }
});

module.exports = router;
