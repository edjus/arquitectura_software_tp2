// Load config
const config   = require('./config');

// Import libraries
const express     = require('express');
const got         = require('got');
const redis       = require('redis');
const {promisify} = require('util');

// Setup cache keys
const cacheKeyPrefix = 'key-';

// Create redis client and monkey-patch it to use Promises
config.redis.retryStrategy = (options) => {
  if (options.error.code === 'ECONNREFUSED') {
    // This will suppress the ECONNREFUSED unhandled exception
    // that results in app crash
    console.log('Swallowing error of trying to connect to non-existing Redis server');
    return;
  }
  console.log('Got another error when starting redis:', options.error);
};

const redisClient = redis.createClient(config.redis);
for (let method of ['set', 'get', 'flushdb']) {
  redisClient[method] = promisify(redisClient[method]);
}

// Initialize datadog client
const connectDatadog = require('connect-datadog')(config.datadog);

// Create app
const app = express();

// Set app to use the datadog middleware
app.use(connectDatadog);

// Routes
app.get('/', (req, res) => res.send('Hello World!'));
app.get('/remote', wrapped(getRemoteValue));
app.get('/alternate', wrapped(getAlternateValue));
app.get('/remote/cached', wrapped(getCached));
app.delete('/remote/cached', delCached);

// Start app
app.listen(3000, () => console.log('Example app listening on port 3000!'));

// --- Request handlers ---

function wrapped(handler) {
  return async (req, res) => {
    try {
      const response = await handler();
      res.status(200).set({"Cache-Control":"no-cache, no-store, must-revalidate"}).send(response);
    } catch (error) {
      res.status(500).send(error);
    }
  }
}

async function getRemoteValue() {
  const response = await got(`${config.remoteBaseUri}/sleep/1`);
  return response.body;
}

async function getAlternateValue() {
  const response = await got(`${config.alternateUrl}`);
  return response.body;
}

async function getCached() {
  // Id to be used just for debugging, to identify which request some logs belong to
  const reqId = Math.random().toString().slice(2, 11);
  const cacheKey = cacheKeyPrefix + Math.floor(Math.random()*config.cacheKeyLength);

  debug(reqId, 'checking cache ['+cacheKey+']...');
  let value = await redisClient.get(cacheKey);

  if (!value) {
    debug(reqId, 'hitting remote service to set cache...');
    value = await getRemoteValue();

    debug(reqId, 'setting cache (asynchronously)...');
    redisClient.set(cacheKey, value).then(() => debug(reqId, 'cache set.'));
  }

  debug(reqId, 'answering');
  return value;
}

async function delCached(req, res) {
  try {
    debug('deleting cache contents...');
    await redisClient.flushdb();
    res.status(204).send();
  } catch (error) {
    res.status(500).send(error);
  }
}

// --- helper functions ---

function debug(...args) {
  if (!config.debug) {
    return;
  }

  console.log(...args);
}
