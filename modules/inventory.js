var express = require('express');
var router = express.Router();


router.get('/', async (req,res)=>{
    "Here express will pull data from the database and return it in this form"
    let results = [{
        segment:"Karta Graficzna",
        partName:"Gigabyt Płyta główna coś tam coś tam",
        quantity:6,
        nettoPrice:2600,
        value:this.quantity*this.nettoPrice,
        dataZakupu:Date,
        dostawca:"ks edmunt"
    },
    {
        segment:"Karta asfa",
        partName:"Gigabyt Płyta główna coś tam coś tam",
        quantity:6,
        nettoPrice:2600,
        value:this.quantity*this.nettoPrice,
        dataZakupu:Date,
        dostawca:"ks edmunt"
    }]
    
})

router.get('/inventory/:id',async (req,res)=>{
    "Here express will pull id individual data from the database and return it in this form"
    let results = {
        segment:"Karta Graficzna",
        partName:"Gigabyt Płyta główna coś tam coś tam",
        quantity:6,
        nettoPrice:2600,
        value:this.quantity*this.nettoPrice,
        dataZakupu:Date,
        dostawca:"ks edmunt"
    }
})

router.post('/inventory-add/', async (req,res)=>{
    "Here all the arguments like segment, model name, amount, price will be passed"
})

router.post('/inventory-sell/', async (req, res) =>{
    "In the options the individual ids of parts will be passed for the backend to delete"
})



module.exports = router;