/**
 * Centralized API Error Handling Middleware
 */
const errorHandler = (err, req, res, next) => {
  console.error('💥 Central API Error:', err.message || err);

  const statusCode = err.status || err.statusCode || 500;
  const message = err.message || 'Internal API Server Error';

  res.status(statusCode).json({
    success: false,
    error: message,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
  });
};

module.exports = errorHandler;
