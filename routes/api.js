const express = require('express');
const router = express.Router();
const db = require('../config/database');
const { ensureAuthenticated, ensureAdmin } = require('../middleware/authbackup');

router.get('/auth/status', (req, res) => {
    if (req.session && req.session.userId) {
        return res.json({
            authenticated: true,
            user: {
                id: req.session.userId,
                role: req.session.userRole,
                name: req.session.userName
            }
        });
    }

    res.json({ authenticated: false});
});


// API endpoint for dashboard data
router.get('/dashboard', ensureAuthenticated, ensureAdmin, async (req, res) => {
    try {
        const { start_date, end_date, category, sort_by = 'order_date', sort_order = 'DESC' } = req.query;
        
        let query = `
            SELECT 
                o.order_id,
                u.name as customer_name,
                o.order_date,
                o.total_amount,
                o.status,
                COUNT(oi.product_id) as product_count,
                STRING_AGG(p.name, ', ') as products_ordered
            FROM orders o
            JOIN users u ON o.user_id = u.user_id
            JOIN order_items oi ON o.order_id = oi.order_id
            JOIN products p ON oi.product_id = p.product_id
            WHERE 1=1
        `;
        
        const params = [];
        
        if (start_date) {
            query += ' AND DATE(o.order_date) >= ?';
            params.push(start_date);
        }
        
        if (end_date) {
            query += ' AND DATE(o.order_date) <= ?';
            params.push(end_date);
        }
        
        if (category) {
            query += ' AND p.category = ?';
            params.push(category);
        }
        
        query += ` GROUP BY o.order_id ORDER BY ${sort_by} ${sort_order}`;
        
        const orders = await db.query(query, params);
        
        // Get categories for filter
        const categoriesQuery = 'SELECT DISTINCT category FROM products ORDER BY category';
        const categoryResults = await db.query(categoriesQuery);
        const categories = categoryResults.map(row => row.category);
        
        res.json({
            success: true,
            orders,
            categories,
            filters: req.query,
            user: req.user
        });
    } catch (error) {
        console.error('Dashboard API error:', error);
        res.json({ success: false, message: error.message });
    }
});

module.exports = router;