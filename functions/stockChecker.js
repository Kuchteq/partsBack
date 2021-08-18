const pool = require('../db');

const checkStock = items => {
  return new Promise((resolve, reject) => {
    if (items.length == 0) {
      resolve('No checking');
      return;
    }

    let itemsToCheck = {
      ids: [],
      quantities: [],
    };

    items.forEach(item => {
      itemsToCheck.ids.push(item.part_id);
      itemsToCheck.quantities.push(item.quantity);
    });

    pool.query(
      `SELECT stock_checker(ARRAY ${JSON.stringify(itemsToCheck.ids)}, ARRAY ${JSON.stringify(itemsToCheck.quantities)});`,
      [],
      (err, qResults) => {
        qResults.rows[0].stock_checker ? resolve() : reject('No part stock available');
      }
    );
  });
};

module.exports = checkStock;
