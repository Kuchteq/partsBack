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

/*
  Creating the instance of express object which is the main framework used for backend, 
  through this object, you define routes and add middleware to this object
*/
const app = express();

const PORT = 5000; //Defining on which port the server will be running

const verifyUser = (req, res, next) => {
  //function used for authentication that looks into the authorization request cookie
  token = req.cookies.Authorization;
  if (!token) return res.sendStatus(403);

  //Verify the user by their json webtoken
  jwt.verify(token, 'secretkey', (err, data) => {
    if (err) {
      //If the token validation is not successful do not proceed to execute the apprropriate
      //route controller only return 403 status code
      res.sendStatus(403);
    } else {
      //Fulfill the rest of the request
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

/*Establishing CORS policy for the app to allow cross-origin requests, 
i.e. requests from different ports, since sveltekit utilities run on different one */
app.use(
  cors({
    origin: ['http://localhost:3000', 'http://localhost:5000'],
    credentials: true,
  })
);

//Middleware used for parsing the body of the request and cookies
app.use(express.json());
app.use(cookieParser());

//Before every request, make sure that the routes are protected by imporitng the previously created middleware
app.use(protectRoutes);

//Integrate the routes from the module folder
app.use('/', [computers, inventory, suppliers, clients, problems, history, orders, multiSearch, raports]);

const INVALID_CREDS_MESSAGE = 'Invalid login credentials';

app.post('/userlogin', async (req, response) => {
  //route responsible for authenticating the user
  const { username, password } = req.body;

  await pool.query('SELECT * FROM users WHERE username = $1', [username], async (err, queryResults) => {
    try {
      if (queryResults.rowCount !== 1) return response.status(401).send(INVALID_CREDS_MESSAGE);

      bcrypt.compare(password, queryResults.rows[0].password, async (err, result) => {
        if (result == true) {
          jwt.sign(queryResults.rows[0], 'secretkey', { expiresIn: '14d' }, (err, token) => {
            /* setting an httpOnly cookies in order to prevent the cookie from being read by the client
            side javascript code for security reasons, this cookie stays only on the server side */
            response
              .status(202)
              .cookie('Authorization', token, {
                httpOnly: true,
                expires: dayjs().add(14, 'days').toDate(),
              })
              .send('successfully logged in');
          });
        } else {
          //If the password is not correct, return a 401 status
          return response.status(401).send(INVALID_CREDS_MESSAGE);
        }
      });
    } catch (err) {
      //If the query fails, return the error
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

//This starts the service on the specified port 
app.listen(PORT, () => {
  console.log(`Back-end service stared at http://localhost:${PORT}`);
});
