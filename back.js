const express = require('express');
const pool = require("./db")
const cors = require('cors')
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');

let inventory = require('./modules/inventory');


const saltRounds = 10;
const myPlaintextPassword = 'DWAtesty123';
const someOtherPlaintextPassword = 'not_bacon';

var protectRoutes = function(req, res, next) {
    if(req._parsedUrl.pathname === '/userlogin') {
        next();
    } else {
        verifyUser(req, res, next);
    }
}
verifyUser = (req, res, next) => {
    let token = req.headers["authorization"];

    if (!token) return res.sendStatus(403);

    token = token.split(' ')[1]

    jwt.verify(token, 'secretkey', (err, data) => {
        if(err) {
            res.sendStatus(403);
        } 
        else 
        {
            next();
        }
    })
  };


//pass is DWAtesty123

bcrypt.genSalt(saltRounds, async (err, salt) => {
    bcrypt.hash("DWAtesty123", salt, async (err, hash) => {
        // Store hash in your password DB.
        hashedPass = await hash;
    });
});


const app = express();
app.use(protectRoutes)
app.use('/inventory', inventory);


const invalidCredsMessage = "Invalid login credentials"

let port = 3000

app.use(express.json());
app.use(cors())



app.post("/userlogin", async (req,response)=>{
    const { email, password, username } = req.body

    let userPass = await pool.query("SELECT * FROM users WHERE username = $1",[username], async (err,queryResults)=>{
        try
        {
            if(queryResults.rowCount != 1) return response.status(400).send(invalidCredsMessage);

            await bcrypt.compare(password, queryResults.rows[0].password, async (err, result) => {
                if(result == true)
                {
                    jwt.sign(queryResults.rows[0], 'secretkey', { expiresIn: '10000s' }, (err, token) => {
                        response.json({
                          token
                        });
                      });
                }
                else
                {
                    return response.status(400).send(invalidCredsMessage);
                }
            });
        }
        catch(err)
        {
            res.send('An error occoured')
        }
        

    })
})

app.post("/e", async(req,res) =>{
    const { email, password, username } = req.body
    try {   
        const userReturn = await pool.query("INSERT INTO users(username, email, password) VALUES ($1, $2, $3) RETURNING *",[username, email,password])
        res.json(userReturn)
    }
    catch (err)
    {
        console.log(err.message)
    }
})

//routes would be protected with jwt





app.get('/reports/', async (req, res) =>{
    "Typically it would pull out the last 3 months of data and display it in , but it could be skipped by an argument skip "
})

app.get('/reports-sheet/', async (req, res) =>{
    `It generates a record based on the options start_at and end_at and returns profit, amount of sales, graph data that says what sectors were most demanded, what was the value demanded,
    best client in terms of amounts of purchases and the most profitable one, from which suppliers were the parts most often bought`
})



app.get('/sets/', async (req, res) =>{
    `It generates a record based on the options start_at and end_at and returns profit, amount of sales, graph data that says what sectors were most demanded, what was the value demanded,
    best client in terms of amounts of purchases and the most profitable one, from which suppliers were the parts most often bought`
})

app.get('/sets/:id', async (req, res) =>{
    `Gives the info about specific computer based on id`
})

app.post('/sets-sell/', async (req, res) =>{
    "In the options an array of the individual ids of computers will be passed for the backend to delete"
})

app.post('/sets-assemble/',async (req,res)=>{
    `In the options there will be different parts ids which will then assemble the computer and add it to the database`
})
app.post('/sets-disassemble/',async (req,res)=>{
    `In the options there will be different parts ids which will then assemble the computer and add it to the database`
})

app.get('/problems/', async (req,res)=>{
    `Get all the problems from the database and return it in an array, options would be if the ones that are being pulled out are finished or not`
})

app.get('/problems/:id', async (req,res)=>{
    `Gets the specific problem based on id`
})


app.post('/problems-add',async (req,res)=>{
    `Add a problem to the database with fields such as computer Id, handInDate, problemNote, deadlineDate`
})

app.post('/problems-finish',async (req,res)=>{
    `Sets the problemFinished field in the database to true`
})



app.get('/clients', async (req,res)=>{
    `Gets all the clients' brief info`
})

app.get('/clients/:id', async (req,res)=>{
    `Gets all the clients' info with purchases`
})

app.post('/clients-add', async (req,res)=>{
    `Add a client with fields such as name dateOfJoining`
})

app.post('/clients-remove', async (req,res)=>{
    `Remove client`
})



app.get('/suppliers', async (req,res)=>{
    `Gets all the suppliers' brief info`
})

app.get('/suppliers/:id', async (req,res)=>{
    `Gets all the suppliers' info with purchases`
})

app.post('/suppliers-add', async (req,res)=>{
    `Add a supplier with fields such as name dateOfJoining`
})

app.post('/clients-remove', async (req,res)=>{
    `Remove supplier`
})


app.listen(port,()=>{
    console.log(`app stared http://localhost:${port}`)
})
