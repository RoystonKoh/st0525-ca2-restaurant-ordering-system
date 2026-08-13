// middleware/auth.js

function ensureAuthenticated(req, res, next) {
  if (req.session && req.session.userId) {

    req.user = {
      user_id: req.session.userId,
      role: req.session.userRole,
      username: req.session.userName
    };

    return next();
  }

  // API request
  if (req.xhr || (req.headers.accept && req.headers.accept.indexOf('json') > -1)) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required'
    });
  }

  // Page request
  return res.redirect('/login');
}

function ensureAdmin(req, res, next) {
  const role = req.session.userRole ? req.session.userRole.toUpperCase() : '';

  if (req.session && req.session.userId && role === 'ADMIN') {

    req.user = {
      user_id: req.session.userId,
      role: req.session.userRole,
      username: req.session.userName
    };
    return next();
  }

  if (req.xhr || (req.headers.accept && req.headers.accept.indexOf('json') > -1)) {
    return res.status(403).json({
      success: false,
      message: 'Admin access required'
    });
  }

  if (req.session && req.session.userId) {
    return res.status(403).send('Access denied. Admin privileges required.');
  }

  return res.redirect('/login');
}

function ensureCustomer(req, res, next) {
  const role = req.session.userRole ? req.session.userRole.toUpperCase() : '';

  if (req.session && req.session.userId && role === 'USER') {

    req.user = {
      user_id: req.session.userId,
      role: req.session.userRole,
      username: req.session.userName
    };

    return next();
  }

  if (req.xhr || (req.headers.accept && req.headers.accept.indexOf('json') > -1)) {
    return res.status(403).json({
      success: false,
      message: 'Customer access required'
    });
  }

  if (req.session && req.session.userId) {
    return res.redirect('/dashboard');
  }

  return res.redirect('/login');
}

function redirectIfAuthenticated(req, res, next) {
  if (req.session && req.session.userId) {
    const role = req.session.userRole ? req.session.userRole.toUpperCase() : '';
    const redirectUrl = role === 'ADMIN' ? '/dashboard' : '/member/products';
    return res.redirect(redirectUrl);
  }
  return next();
}

module.exports = {
  ensureAuthenticated,
  ensureAdmin,
  ensureCustomer,
  redirectIfAuthenticated
};
