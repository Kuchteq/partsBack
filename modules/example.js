//1) call the appropriate function corresponding to the HTTP method (GET, POST, PUT, DELETE) ex.
//2) declare the query string modifying it accordingly if needed
//2.5) validate request body - only applicable to POST and PUT
//3) call the query function on the pool variable to execute the query
//4) if the query is successful, return the result to the client
//4.5) if some database changes were made, register the changes in the database in the history table
//5) if the query is not successful, return the error to the client


//1) call GET method on the router object inside of the callback of that function you create controller handles the request
router.get('/routename', async (request, response) => {

    //2) declare the query string with sorting and filtering
    const QS = withParams(
        `SELECT id, column_1, column_2, column_3... FROM table 
    LEFT JOIN other_table ON (id = other_table.column_other)`,
        request.query.page, request.query.sort_by, request.query.sort_dir, request.query.s, ['table_name']
    );

    //3) use the pool variable to make query to the database
    pool.query(QS, async (err, qResults) => {
        if (err) {
            //5) if there is an error, log it inside the console and send an error about inapropriate request to the client
            console.log(err);
            response.status(400).send(BODY_ERROR);
        } else {
            //4) if everything is all right with the query, the results are sent to the client
            response.status(200).send(qResults.rows);
        }
    });
});

//1) call POST method on the router object inside of the callback of that function you create controller that handles the request
router.post('/routename:pathparam', async (request, response) => {

    //2) declare the query string for inserting data 
    const QS = `INSERT INTO table (column_1, column_2, column_3... ) VALUES ($1, $2, $3... )`
    try {
        //2.5) validate request body
        await PARTS_ADD_SCHEMA.validate(req.body);
        pool.query(QS, Object.values(req.body), (err, qResults) => {
            if (err) {
                //5) if there is an error, log it inside the console and send an error about inapropriate request to the client
                console.log('SQL problem ' + err);
                res.status(406).send(BODY_ERROR);
            } else {
                //4) if everything is all right with the query, the responseults are sent to the client
                registerEvent(EVENT_CODE, qResults.rows[0].id, req.body.part_name); //4.5) register changes in the database
                res.status(200).send(INSERT_SUCCESS);
            }
        });
    } catch (err) {
        //5) if there is an error, log it inside the console and send an error about inapropriate request to the client
        console.log('Data validation problem ' + err);
        res.status(406).send(BODY_ERROR);
    }

});



//1) call GET method on the router object inside of the callback of that function you create controller that handles the request
router.get('/routename:pathparam', async (request, response) => {

    //2) declare the query string with sorting and filtering
    const QS = `SELECT id, column_1, column_2, column_3... FROM table 
    LEFT JOIN other_table ON (column_1 = other_table.column_other)
    WHERE id = $1`

    //3)use the pool variable to make query to the database
    pool.query(QS, [request.params.pathparam], async (err, qResults) => {
        if (err) {
            //if there is an error, log it inside the console and send an error about inapropriate request to the client
            console.log(err);
            response.status(400).send(BODY_ERROR);
        } else {
            //4) if everything is all right with the query, the results are sent to the client
            response.status(200).send(qResults.rows);
        }
    });
});

