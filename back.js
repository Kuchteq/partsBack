/* eslint-disable quotes */
/* eslint-disable no-unused-expressions */

//Importing the necessary libraries/tools
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const pool = require('./db');
const cookieParser = require('cookie-parser');
const dayjs = require('dayjs');

//importing the self-made modules
const inventory = require('./modules/inventory');
const suppliers = require('./modules/suppliers');
const clients = require('./modules/clients');
const computers = require('./modules/computers');
const problems = require('./modules/problems');
const history = require('./modules/history');
const orders = require('./modules/orders');
const raports = require('./modules/raports');
const multiSearch = require('./modules/multiSearch');

const saltRounds = 10;

/*
  Creating the instance of express object which is the main framework used for backend, 
  through this object, you define routes and add middlaware
*/
const app = express();

//function used for authentication by that looks into the authorization request cookie
const verifyUser = (req, res, next) => {
  token = req.cookies.Authorization;
  if (!token) return res.sendStatus(403);

  //Verify the user by their json webtoken
  jwt.verify(token, 'secretkey', (err, data) => {
    if (err) {
      //If the token validation is not successful don't proceed to do any other functions on that route, return only 403 status
      res.sendStatus(403);
    } else {
      //Do the rest of the request
      next();
    }
  });
};

const protectRoutes = (req, res, next) => {
  //Every route in the app is protected except the log in one
  if (req._parsedUrl.pathname === '/userlogin') {
    next();
  } else {
    verifyUser(req, res, next);
  }
};

app.use(
  cors({
    origin: ['http://localhost:3000', 'http://localhost:5000'],
    credentials: true,
  })
);

app.use(cookieParser());
app.use(express.json());

//Before every request, make sure that the routes are protected by importing the previously created middleware
app.use(protectRoutes);

//Use the routes from the module folder
app.use('/', [computers, inventory, suppliers, clients, problems, history, orders, multiSearch, raports]);

const invalidCredsMessage = 'Invalid login credentials';

const port = 5000;

app.post('/userlogin', async (req, response) => {
  //route responsible for authenticating the user
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

app.post('/userlogout', async (req, response) => {
  //Route that deletes the HTTPonly cookie
  token = req.cookies.Authorization;
  response.clearCookie('Authorization');
  response.send('logged out');
});

app.listen(port, () => {
  console.log(`app stared http://localhost:${port}`);
});
