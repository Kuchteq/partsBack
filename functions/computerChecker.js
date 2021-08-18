const pool = require('../db');

const checkComputerExistance = ids => {
  return new Promise((resolve, reject) => {
    //first argument are the ids second is the amount you want to subtract
    if (ids.length == 0) {
      resolve('Only parts order');
      return;
    }
    ids.every(id =>
      pool.query('SELECT id FROM computers WHERE id = $1', [id], (err, qResults) => {
        if (qResults.rowCount > 0) {
          resolve();
        } else {
          reject(`Computer of id ${id} does not exist`);
          return;
        }
      })
    );
  });
};

module.exports = checkComputerExistance;
