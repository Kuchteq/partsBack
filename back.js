/* eslint-disable quotes */
/* eslint-disable no-unused-expressions */
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const pool = require('./db');
const cookieParser = require('cookie-parser');
const dayjs = require('dayjs');

const inventory = require('./modules/inventory');
const suppliers = require('./modules/suppliers');
const clients = require('./modules/clients');
const computers = require('./modules/computers');
const problems = require('./modules/problems');
const history = require('./modules/history');
const orders = require('./modules/orders');
const misc = require('./modules/misc');
const multiSearch = require('./modules/multiSearch');

const saltRounds = 10;
const myPlaintextPassword = 'DWAtesty123';
const someOtherPlaintextPassword = 'not_bacon';

const app = express();

const verifyUser = (req, res, next) => {
  token = req.cookies.Authorization;

  if (!token) return res.sendStatus(403);

  jwt.verify(token, 'secretkey', (err, data) => {
    if (err) {
      res.sendStatus(403);
    } else {
      next();
    }
  });
};

const protectRoutes = (req, res, next) => {
  if (req._parsedUrl.pathname === '/userlogin') {
    next();
  } else {
    verifyUser(req, res, next);
  }
};
// pass is DWAtesty123

bcrypt.genSalt(saltRounds, async (err, salt) => {
  bcrypt.hash('DWAtesty123', salt, async (err, hash) => {
    // Store hash in your password DB.
    hashedPass = await hash;
  });
});

app.use(
  cors({
    origin: ['http://localhost:3000', 'http://localhost:5000'],
    credentials: true,
  })
);

app.use(cookieParser());
app.use(express.json());
//app.use(protectRoutes);
app.use('/', [computers, inventory, suppliers, clients, problems, history, orders, misc, multiSearch]);

const invalidCredsMessage = 'Invalid login credentials';

const port = 5000;

app.post('/userlogin', async (req, response) => {
  const { _email, username, password } = req.body;

  const userPass = await pool.query('SELECT * FROM users WHERE username = $1', [username], async (err, queryResults) => {
    try {
      if (queryResults.rowCount !== 1) return response.status(401).send(invalidCredsMessage);

      bcrypt.compare(password, queryResults.rows[0].password, async (err, result) => {
        if (result == true) {
          jwt.sign(queryResults.rows[0], 'secretkey', { expiresIn: '9999999s' }, (err, token) => {
            response
              .status(202)
              .cookie('Authorization', token, {
                httpOnly: true,
                expires: dayjs().add(30, 'days').toDate(),
              })
              .send('successfully logged in');
          });
        } else {
          return response.status(401).send(invalidCredsMessage);
        }
      });
    } catch (err) {
      res.send('An error occoured');
    }
  });
});

app.post('/e', async (req, res) => {
  const { email, password, username } = req.body;
  try {
    const userReturn = await pool.query('INSERT INTO users(username, email, password) VALUES ($1, $2, $3) RETURNING *', [
      username,
      email,
      password,
    ]);
    res.json(userReturn);
  } catch (err) {
    console.log(err.message);
  }
});

// routes would be protected with jwt

app.get('/reports/', async (req, res) => {
  'Typically it would pull out the last 3 months of data and display it in , but it could be skipped by an argument skip ';
});

app.get('/reports-sheet/', async (req, res) => {
  `It generates a record based on the options start_at and end_at and returns profit, amount of sales, graph data that says what sectors were most demanded, what was the value demanded,
    best client in terms of amounts of purchases and the most profitable one, from which suppliers were the parts most often bought`;
});

app.get('/sets/', async (req, res) => {
  `It generates a record based on the options start_at and end_at and returns profit, amount of sales, graph data that says what sectors were most demanded, what was the value demanded,
    best client in terms of amounts of purchases and the most profitable one, from which suppliers were the parts most often bought`;
});

app.get('/sets/:id', async (req, res) => {
  `Gives the info about specific computer based on id`;
});

app.post('/sets-sell/', async (req, res) => {
  'In the options an array of the individual ids of computers will be passed for the backend to delete';
});

app.post('/sets-assemble/', async (req, res) => {
  `In the options there will be different parts ids which will then assemble the computer and add it to the database`;
});
app.post('/sets-disassemble/', async (req, res) => {
  `In the options there will be different parts ids which will then assemble the computer and add it to the database`;
});

app.get('/problems/:id', async (req, res) => {
  `Gets the specific problem based on id`;
});

app.post('/problems-add', async (req, res) => {
  `Add a problem to the database with fields such as computer Id, handInDate, problemNote, deadlineDate`;
});

app.post('/problems-finish', async (req, res) => {
  `Sets the problemFinished field in the database to true`;
});

app.get('/clients', async (req, res) => {
  `Gets all the clients' brief info`;
});

app.get('/clients/:id', async (req, res) => {
  `Gets all the clients' info with purchases`;
});

app.post('/clients-add', async (req, res) => {
  `Add a client with fields such as name dateOfJoining`;
});

app.post('/clients-remove', async (req, res) => {
  `Remove client`;
});

app.get('/suppliers', async (req, res) => {
  `Gets all the suppliers' brief info`;
});

app.get('/suppliers/:id', async (req, res) => {
  `Gets all the suppliers' info with purchases`;
});

app.post('/suppliers-add', async (req, res) => {
  `Add a supplier with fields such as name dateOfJoining`;
});

app.post('/clients-remove', async (req, res) => {
  `Remove supplier`;
});

app.listen(port, () => {
  console.log(`app stared http://localhost:${port}`);
});
