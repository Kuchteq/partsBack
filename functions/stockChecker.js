const pool = require('../db');

const checkStock = items => {
  return new Promise((resolve, reject) => {
    let itemsToCheck = {
      ids: [],
      quantities: [],
    };
    items.forEach(item => {
      itemsToCheck.ids.push(item.part_id);
      itemsToCheck.quantities.push(item.quantity);
    });

    //first argument are the ids second is the amount you want to subtract
    pool.query(
      `SELECT stock_checker(ARRAY ${JSON.stringify(itemsToCheck.ids)}, ARRAY ${JSON.stringify(itemsToCheck.quantities)});`,
      [],
      (err, qResults) => {
        qResults.rows[0].stock_checker ? resolve() : reject('No stock available');
      }
    );
  });
};

module.exports = checkStock;
