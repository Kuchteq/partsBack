const pool = require('../db');

`
    Action ids and their meaning
    0 - Inventory added {inventory_name}
    1 - Inventory updated {inventory_name}
    2 - Inventory deleted {inventory_name}
    3 - Order created {title}
    4 - Order deleted {title}
    5 - Computer assembled {computer_name}
    6 - Computer modified {computer_name}
    7 - Computer disassembled {computer_name}
    8 - Problem created {problem_note}
    9 - Problem modified {problem_note}
    10 - Problem resolved {problem_note}
    11 - Problem deleted {problem_note}
    12 - Client added {client_name}
    13 - Client modified {client_name}
    14 - Client deleted {client_name}
    15 - Supplier added {supplier_name}
    16 - Supplier modified {supplier_name}
    17 - Supplier deleted {supplier_name}
`;

const registerEvent = (action_id, target_id, target_value) => {
  return new Promise(async (resolve, reject) => {
    pool.query(
      `INSERT INTO history (action_id, target_id, details, at_time) VALUES ($1, $2, $3, NOW())`,
      [action_id, target_id, target_value],
      async (err, qResults) => {
        if (err) {
          reject(err);
          console.log('SQL problem ' + err);
        } else {
          resolve('successfully recorded event');
        }
      }
    );
  });
};

module.exports = registerEvent;
