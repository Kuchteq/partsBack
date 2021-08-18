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

const registerEvent = (action_id, target_id) => {
  return new Promise(async (resolve, reject) => {
    let category;
    let targetValue = target_id;
    let tableName;

    if (action_id >= 0 && action_id < 3) {
      category = 'part_id';
      tableName = 'parts';
    } else if (action_id >= 3 && action_id < 5) {
      category = 'order_id';
      tableName = 'orders';
    } else if (action_id >= 5 && action_id < 8) {
      category = 'computer_id';
      tableName = 'computers';
    } else if (action_id >= 8 && action_id < 12) {
      category = 'problem_id';
      tableName = 'problems';
    } else if (action_id >= 12 && action_id < 15) {
      category = 'client_id';
      tableName = 'clients';
    } else if (action_id >= 15 && action_id < 18) {
      category = 'supplier_id';
      tableName = 'suppliers';
    }

    new Promise((resolveIn, rejectIn) => {
      if (action_id == 2 || action_id == 4 || action_id == 7 || action_id == 11 || action_id == 14 || action_id == 17) {
        pool.query(
          `SELECT ${tableName == 'problems' ? 'problem_note' : 'name'} FROM ${tableName} WHERE id = $1`,
          [targetValue],
          (err, qResults1) => {
            if (qResults1.rowCount > 0) {
              targetValue = qResults1.rows[0].name;
              category = 'special_delete';
              resolveIn();
            } else {
              rejectIn(err);
            }
          }
        );
      }
    })
      .then(() => {
        pool.query(`INSERT INTO history ( action_id, ${category} ) VALUES ($1, $2)`, [action_id, targetValue], async (err, qResults) => {
          if (err) {
            reject(err);
            console.log('SQL problem ' + err);
          } else {
            resolve('successfully recorded event');
          }
        });
      })
      .catch(err => resolve('Thing doesnt exist ' + err));
  });
};

module.exports = registerEvent;
