const express = require('express');
const yup = require('yup');
const router = express.Router();
const pool = require('../db');
const withParams = require('../functions/withParams');
const checkStock = require('../functions/stockChecker');
const checkComputerExistance = require('../functions/computerChecker.js');
const registerEvent = require('../functions/registerEvent');

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
const computersUpdateSchema = yup.object().shape({
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
  pieces_update: yup
    .array()
    .of(
      yup.object().shape({
        piece_id: yup.number().required(),
        part_id: yup.number().required(),
        quantity_difference: yup.number().required(),
        to_delete: yup.boolean().required(),
      })
    )
    .required(),
});

router.get('/computers', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  const returnComputersQS = withParams('SELECT * FROM get_computers()', req.query.page, req.query.sort_by, req.query.sort_dir);

  pool.query(returnComputersQS, async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});

router.get('/computers/:id', async (req, res) => {
  'Here express will pull id individual data from the database and return it in this form';

  const partsQS = `SELECT computer_pieces.id as piece_id, parts.id as part_id, parts.name as part_name, computer_pieces.quantity as quantity,  parts.price as price, 
  jsonb_build_object('value', segments.id, 'label', segments.name) as segment_obj
  FROM computer_pieces JOIN parts on parts.id = computer_pieces.part_id JOIN computers on computers.id = computer_pieces.belonging_computer_id
  JOIN segments on segments.id = parts.segment_id
  WHERE computers.id = $1 ORDER BY segment_id`;

  const compInfoQS = `SELECT computers.id as computer_id, computers.name as computer_name, SUM(parts.price) computer_value, 
  computers.short_note as short_note,
  TO_CHAR(computers.assembled_at :: DATE, 'dd/mm/yyyy hh:mm') AS assembled_at FROM computers
  LEFT JOIN computer_pieces ON computer_pieces.belonging_computer_id = computers.id LEFT JOIN parts on parts.id = computer_pieces.part_id
  WHERE computers.id = $1 GROUP BY computers.id;`;
  pool.query(compInfoQS, [req.params.id], async (err, q1Results) => {
    if (!err && q1Results.rows.length > 0)
      pool.query(partsQS, [req.params.id], async (err, q2Results) => {
        if (err) {
          console.log(err);
          res.status(400).send(bodyErrror);
        } else {
          let response = q1Results.rows[0];
          response.parts = q2Results.rows;
          res.status(200).send(response);
        }
      });
    else res.status(400).send(bodyErrror + " or the computer doesn't exist");
  });
});

router.post('/computers', async (req, res) => {
  ('Here express will pull data from the database and return it in this form');

  const pieces = req.body.pieces;

  const newComputerQS = 'INSERT INTO computers (name, assembled_at, short_note) VALUES ($1, $2, $3) RETURNING id;';
  const createPieceQS = 'INSERT INTO computer_pieces (part_id, quantity, belonging_computer_id) VALUES ($1, $2, $3);';
  const subtractStockQS = 'UPDATE parts SET stock = stock - $1 WHERE id = $2';

  checkStock(pieces)
    .then(() => {
      pool.query(newComputerQS, [req.body.computer_name, req.body.assembled_at, req.body.short_note], (err, q2Results) => {
        if (!err) {
          const newComputerId = q2Results.rows[0].id;

          pieces.map(piece => {
            pool.query(createPieceQS, [piece.part_id, piece.quantity, newComputerId]).catch(err => console.log(err));

            //subtract approriate amount from stock
            pool.query(subtractStockQS, [piece.quantity, piece.part_id]);
          });
          registerEvent(5, newComputerId, req.body.computer_name); // add the newly created item/person to the history
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

router.put('/computers/:id', async (req, res) => {
  ('Here express will pull data from the database and return it in this form');

  const pieces = req.body.pieces;
  const computerId = req.params.id;
  const modifyComputerQS = 'UPDATE computers SET name = $1, assembled_at = $2 WHERE id = $3;';
  const updatePieceQS = 'UPDATE computer_pieces SET part_id = $1, quantity = $2 WHERE id = $3';
  const deletePieceQS = 'DELETE FROM computer_pieces WHERE id = $1';
  const subtractStockQS = 'UPDATE parts SET stock = stock - $1 WHERE id = $2';
  const addStockQS = 'UPDATE parts SET stock = stock + $1 WHERE id = $2';
  const createPieceQS = 'INSERT INTO computer_pieces (part_id, quantity, belonging_computer_id) VALUES ($1, $2, $3);';
  const getPartsInfoQS = 'SELECT id as piece_id, part_id, quantity FROM computer_pieces WHERE belonging_computer_id = $1 ORDER BY piece_id;';
  checkStock(pieces)
    .then(() => {
      pool.query(modifyComputerQS, [req.body.computer_name, req.body.assembled_at, computerId], (err, q2Results) => {
        pool.query(getPartsInfoQS, [computerId]).then(q1Results => {
          let newly = pieces.filter(p => !p.piece_id);
          let older = pieces.filter(p => p.piece_id); //older as if the piece id is still there, though the part_id or quantity may be different

          q1Results.rows.filter(r => r.piece_id);
          try {
            q1Results.rows.forEach(row => {
              let sewc = older.find(o => o.piece_id == row.piece_id && (o.part_id != row.part_id || o.quantity != row.quantity)); //still exists but with changes

              //checking whether the piece doesn't exist inside new computer setup, then deleting it from the current one
              if (!older.find(o => o.piece_id == row.piece_id)) {
                pool.query(addStockQS, [row.quantity, row.part_id]).catch(err => console.log(err));
                pool.query(deletePieceQS, [row.piece_id]).catch(err => console.log(err));
              }
              //checking whether the piece id still exists and whether there are some changes
              else if (sewc) {
                pool.query(addStockQS, [row.quantity, row.part_id]).catch(err => console.log(err));
                pool.query(subtractStockQS, [sewc.quantity, sewc.part_id]).catch(err => console.log(err));
                pool.query(updatePieceQS, [sewc.part_id, sewc.quantity, sewc.piece_id]).catch(err => console.log(err));
              }
            });
            newly.forEach(newRow => {
              pool.query(createPieceQS, [newRow.part_id, newRow.quantity, computerId]).catch(err => console.log(err));
              pool.query(subtractStockQS, [newRow.quantity, newRow.part_id]).catch(err => console.log(err));
            });
            res.status(200).send('wykonane');
            return;
          } catch (err) {
            res.status(400).send('Error has occoured');
            console.log(err);
          }
        });
      });
    })
    .catch(err => {
      res.status(406).send(err);
    });
});

router.delete('/computers/:id', async (req, res) => {
  ('Here express will pull data from the database and return it in this form');

  const getPiecesQS = `SELECT computer_pieces.id as piece_id, computer_pieces.part_id as part_id, computer_pieces.quantity as quantity
  FROM computer_pieces JOIN computers on computers.id = computer_pieces.belonging_computer_id WHERE computers.id = $1;`;

  const deleteComputerQS = 'DELETE FROM computers WHERE id = $1 RETURNING name;';
  const deletePieceQS = 'DELETE FROM computer_pieces WHERE id = $1';
  const addStockQS = 'UPDATE parts SET stock = stock + $1 WHERE id = $2';

  checkComputerExistance([req.params.id])
    .then(() => {
      pool.query(getPiecesQS, [req.params.id], (err, q1Results) => {
        q1Results.rows.map(piece => {
          pool.query(deletePieceQS, [piece.piece_id]).catch(err => console.log(err));

          //add approriate amount from stock
          pool.query(addStockQS, [piece.quantity, piece.part_id]).catch(err => console.log(err));
        });

        pool.query(deleteComputerQS, [req.params.id], (err, q2Results) => {
          if (!err) {
            registerEvent(7, req.params.id, q2Results.rows[0].name);
            res.status(200).send('Computer disassembled');
          } else {
            console.log('SQL problem ' + err);
            res.status(406).send(bodyErrror);
          }
        });
      });
    })
    .catch(err => {
      res.status(406).send(err);
    });
});

router.get('/computer-list', async (req, res) => {
  'Here express will pull data from the database and return it in this form';

  pool.query('SELECT id as value, name as label FROM computers ORDER by id', async (err, qResults) => {
    if (err) {
      console.log(err);
      res.status(400).send(bodyErrror);
    } else {
      res.status(200).send(qResults.rows);
    }
  });
});
module.exports = router;
