const express = require('express');
const session = require('express-session');
const bodyParser = require('body-parser');
const path = require('path');
require('dotenv').config();

const authRoutes = require('./routes/auth');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());

// Session configuration
app.use(session({
    secret: process.env.SESSION_SECRET || 'your-secret-key',
    resave: false,
    saveUninitialized: false,
}));

//serve static assets only 
app.use(express.static('public'));
//Mount auth routes at the ROOT
app.use('/', require('./routes/auth'));

app.use('/dashboard', require('./routes/dashboard'));
app.use('/products', require('./routes/products'));
app.use('/member', require('./routes/productsPage'));
app.use('/feedback', require('./routes/feedback'));
app.use('/responses', require('./routes/responses'));
app.use('/orders', require('./routes/orders'));
app.use('/cart', require('./routes/cart'));
app.use('/checkout', require('./routes/checkout'));

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
