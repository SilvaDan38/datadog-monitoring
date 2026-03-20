// server.js — Node.js CRUD com Datadog APM + DBM + Security
// Express + Sequelize + PostgreSQL + dd-trace

'use strict';
require('dotenv').config(); // carrega .env

// ─── Datadog — DEVE ser a primeira importação ─────────────────────────────────
const tracer = require('dd-trace').init({
  service:     process.env.DD_SERVICE || 'nodejs-crud',
  env:         process.env.DD_ENV     || 'dev',
  version:     process.env.DD_VERSION || '1.0.5',
  logInjection: true,                  // correlaciona logs com traces
  profiling:   true,                   // CPU/heap profiling contínuo
  runtimeMetrics: true,                // métricas Node.js (GC, event loop)
  // DBM: propaga contexto APM → queries SQL
  dbmPropagationMode: 'full',
  // Security (AppSec / IAST)
  appsec: { enabled: process.env.DD_APPSEC_ENABLED === 'true' },
});

const express    = require('express');
const { Sequelize, DataTypes, Op } = require('sequelize');
const StatsD     = require('hot-shots');
const winston    = require('winston');

// ─── Logging estruturado (compatível com Datadog Log Management) ──────────────
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [new winston.transports.Console()]
});

// ─── StatsD — métricas customizadas ──────────────────────────────────────────
const dogstatsd = new StatsD({
  host: process.env.DD_AGENT_HOST || 'localhost',
  port: 8125,
  prefix: 'crud.',
  globalTags: [`service:nodejs-crud`, `env:${process.env.DD_ENV || 'local'}`]
});

// ─── Banco de dados — Sequelize + PostgreSQL ──────────────────────────────────
const sequelize = new Sequelize(
  process.env.DATABASE_URL ||
  'postgresql://user:password@localhost:5432/crud_db',
  {
    dialect: 'postgres',
    logging: (sql) => logger.debug({ msg: 'SQL', sql }),
    pool: { max: 10, min: 2, acquire: 30000, idle: 10000 }
  }
);

const Product = sequelize.define('Product', {
  id:       { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  name:     { type: DataTypes.STRING(100), allowNull: false },
  category: { type: DataTypes.STRING(50), defaultValue: 'general' },
  price:    { type: DataTypes.FLOAT, allowNull: false },
  stock:    { type: DataTypes.INTEGER, defaultValue: 0 },
}, { tableName: 'products', timestamps: true, underscored: true });

// ─── Express App ──────────────────────────────────────────────────────────────
const app = express();
app.use(express.json());

// Middleware — logging de requests + métricas de latência
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    dogstatsd.timing('request.duration', duration, [`route:${req.path}`, `method:${req.method}`, `status:${res.statusCode}`]);
    dogstatsd.increment('request.count', 1, [`route:${req.path}`, `status:${res.statusCode}`]);
    logger.info({ method: req.method, path: req.path, status: res.statusCode, duration_ms: duration });
  });
  next();
});

// ─── Health Check ─────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'nodejs-crud', version: '1.0.0' });
});

// ─── CRUD Products ───────────────────────────────────────────────────────────

// GET /products
app.get('/products', async (req, res) => {
  const span = tracer.startSpan('products.list');
  try {
    const { skip = 0, limit = 100 } = req.query;
    const products = await Product.findAll({ offset: +skip, limit: +limit });
    span.setTag('results.count', products.length);
    dogstatsd.gauge('products.listed', products.length);
    res.json(products);
  } catch (err) {
    span.setTag('error', true);
    span.setTag('error.message', err.message);
    logger.error({ msg: 'list products failed', error: err.message });
    res.status(500).json({ error: err.message });
  } finally {
    span.finish();
  }
});

// GET /products/:id
app.get('/products/:id', async (req, res) => {
  const span = tracer.startSpan('products.get');
  span.setTag('product.id', req.params.id);
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return res.status(404).json({ error: 'Product not found' });
    res.json(product);
  } catch (err) {
    span.setTag('error', true);
    res.status(500).json({ error: err.message });
  } finally {
    span.finish();
  }
});

// POST /products
app.post('/products', async (req, res) => {
  const span = tracer.startSpan('products.create');
  try {
    const { name, category = 'general', price, stock = 0 } = req.body;
    if (!name || price == null) {
      return res.status(400).json({ error: 'name and price are required' });
    }
    const product = await Product.create({ name, category, price, stock });
    span.setTag('product.id', product.id);
    span.setTag('product.name', name);
    dogstatsd.increment('products.created');
    logger.info({ msg: 'Product created', id: product.id, name });
    res.status(201).json(product);
  } catch (err) {
    span.setTag('error', true);
    res.status(500).json({ error: err.message });
  } finally {
    span.finish();
  }
});

// PUT /products/:id
app.put('/products/:id', async (req, res) => {
  const span = tracer.startSpan('products.update');
  span.setTag('product.id', req.params.id);
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return res.status(404).json({ error: 'Product not found' });
    await product.update(req.body);
    dogstatsd.increment('products.updated');
    res.json(product);
  } catch (err) {
    span.setTag('error', true);
    res.status(500).json({ error: err.message });
  } finally {
    span.finish();
  }
});

// DELETE /products/:id
app.delete('/products/:id', async (req, res) => {
  const span = tracer.startSpan('products.delete');
  span.setTag('product.id', req.params.id);
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return res.status(404).json({ error: 'Product not found' });
    await product.destroy();
    dogstatsd.increment('products.deleted');
    res.json({ message: `Product ${req.params.id} deleted` });
  } catch (err) {
    span.setTag('error', true);
    res.status(500).json({ error: err.message });
  } finally {
    span.finish();
  }
});

// ─── Start ────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;

sequelize.sync({ alter: false }).then(() => {
  app.listen(PORT, () => {
    logger.info({ msg: `Node.js CRUD running on port ${PORT}` });
  });
}).catch(err => {
  logger.error({ msg: 'DB connection failed', error: err.message });
  process.exit(1);
});