const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  password: 'DWAtramwaje',
  database: 'parts',
  host: 'localhost',
  port: 5432,
});

module.exports = pool;
