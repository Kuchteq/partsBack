const { Pool } = require('pg');

const pool = new Pool({
  user: 'partsuser',
  password: 'minternal742CZTERY',
  database: 'parts',
  host: 'localhost',
  port: 5432,
});

module.exports = pool;
