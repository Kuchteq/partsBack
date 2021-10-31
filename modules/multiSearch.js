const express = require('express');
const router = express.Router();
const pool = require('../db');
router.use(express.json());

router.get('/multisearch', async (req, res) => {
  'Here express will pull id individual data from the database and return it in this form';

  let sQuery = req.query.s.replaceAll(' ', '+');

  //zrób za pomocą returning ile tych queriesów

  let searchStrings = {
    parts: `SELECT segments.name as segment_name, parts.name as part_name, parts.stock, trim_scale(parts.price),
    suppliers.name as suppliers_name, TO_CHAR(parts.purchase_date :: DATE, 'dd/mm/yyyy') AS purchase_date FROM parts 
    LEFT JOIN suppliers ON (parts.supplier_id = suppliers.id) LEFT JOIN segments ON (parts.segment_id = segments.id)  
    WHERE parts.document_with_weights @@ to_tsquery('"${sQuery}":*') ORDER BY ts_rank(parts.document_with_weights, to_tsquery('"${sQuery}":*'))`,

    computers: `SELECT computers.name as computer_name, SUM(parts.price) computer_value, 
    TO_CHAR(computers.assembled_at :: DATE, 'dd/mm/yyyy hh:mm') AS assembled_at from computers 
    LEFT JOIN computer_pieces ON computer_pieces.belonging_computer_id = computers.id 
    LEFT JOIN parts on parts.id = computer_pieces.part_id
    WHERE computers.document_with_weights @@ to_tsquery('"${sQuery}":*') OR parts.document_with_weights @@ to_tsquery('"${sQuery}":*')
    GROUP BY computers.id ORDER BY ts_rank(computers.document_with_weights, to_tsquery('"${sQuery}":*')) desc;`,

    clients: `SELECT clients.name as client_name, clients.phone, clients.email, TO_CHAR(clients.join_date :: DATE, 'dd/mm/yyyy') AS join_date FROM clients 
    WHERE clients.document_with_weights @@ to_tsquery('"${sQuery}":*') 
    ORDER BY ts_rank(clients.document_with_weights, to_tsquery('"${sQuery}":*'))`,

    suppliers: `SELECT suppliers.name as supplier_name, suppliers.website, TO_CHAR(suppliers.join_date :: DATE, 'dd/mm/yyyy') AS join_date FROM suppliers 
    WHERE suppliers.document_with_weights @@ to_tsquery('"${sQuery}":*') 
    ORDER BY ts_rank(suppliers.document_with_weights, to_tsquery('"${sQuery}":*'))`,

    problems: `SELECT problems.problem_note as problem_note, computers.name as computer_name, 
    TO_CHAR(problems.deadline_date :: DATE, 'dd/mm/yyyy') AS deadline_date FROM problems 
    LEFT JOIN computers ON problems.computer_id = computers.id 
    WHERE problems.document_with_weights @@ to_tsquery('"${sQuery}":*') OR computers.document_with_weights @@ to_tsquery('"${sQuery}":*')
    ORDER BY ts_rank(problems.document_with_weights, to_tsquery('"${sQuery}":*'))`,
  };

  const searchAcross = req.query.across;

  let promises = [];

  searchAcross.forEach(module => {
    promises.push(
      new Promise((resolve, reject) => {
        pool.query(searchStrings[module], async (err, qResults) => {
          if (err) {
            reject(err);
          } else {
            resolve(qResults.rows);
          }
        });
      })
    );
  });

  Promise.all(promises)
    .then(data => {
      res.status(200).send(data);
    })
    .catch(err => {
      console.log(err);
      res.status(400).send(err);
    });
});

module.exports = router;
