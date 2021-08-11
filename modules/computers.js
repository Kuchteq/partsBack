const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const withPaginSort = require('../functions/pagination');
const checkStock = require('../functions/stockChecker');
router.use(express.json());

const bodyErrror = "There's something wrong with data body, see console errors";
const insertSuccess = 'computer added';

const computersSchema = yup.object().shape({
  computer_name: yup.string().required(),
  assembled_at: yup.date().required(),
  pieces: yup
    .array()
    .of(
      yup.object().shape({
        part_id: yup.number().required(),
        quantity: yup.number().required(),
      })
    )
    .required(),
});

router.get('/computers', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  pool.query(wholeQS, async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.post('/computers', async (req, res) => {
  ('Here express will pull data from the database and return it in this form');

  const pieces = req.body.pieces;

  const newComputerQS = 'INSERT INTO computers (name, assembled_at) VALUES ($1, $2) RETURNING id;';
  const createPieceQS = 'INSERT INTO computer_pieces (part_id, quantity, belonging_computer_id) VALUES ($1, $2, $3);';
  const subtractStockQS = 'UPDATE parts SET stock = stock - $1 WHERE id = $2';

  checkStock(pieces)
    .then(() => {
      pool.query(newComputerQS, [req.body.computer_name, req.body.assembled_at], (err, q2Results) => {
        if (!err) {
          const newComputerId = q2Results.rows[0].id;

          pieces.map(piece => {
            pool.query(createPieceQS, [piece.part_id, piece.quantity, newComputerId]).catch(err => console.log(err));

            //subtract approriate amount from stock
            pool.query(subtractStockQS, [piece.quantity, piece.part_id]);
          });
          res.status(200).send('Computer created');
        } else {
          console.log('SQL problem ' + err);
          res.status(406).send(bodyErrror);
        }
      });
    })
    .catch(err => {
      res.status(406).send(err);
    });
});

module.exports = router;
