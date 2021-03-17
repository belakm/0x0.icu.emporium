import helmet from 'helmet'
import express from 'express'
import compression from 'compression';
import bodyParser from 'body-parser'
import { postgraphile, makePluginHook } from 'postgraphile'
import makeAllowedOriginTweak from "./plugins/cors.js"

// allow localhost development
const pluginHook = makePluginHook([
  makeAllowedOriginTweak('http://localhost:1337'),
]);

const app = express()

// compression of responses
app.use(compression())

// headers protection
app.use(helmet())

// body-parser
const { json, urlencoded, text } = bodyParser
app.use(json());
app.use(urlencoded({ extended: false }));
app.use(text({ type: 'application/graphql' }));

// postgraphile
app.use(postgraphile(process.env.DATABASE_URL, '_0x0', {
  watchPg: true,
  graphiql: true,
  enhanceGraphiql: true,
  retryOnInitFail: true,
  jwtSecret: process.env.JWT_SECRET,
  jwtVerifyOptions: {
    audience: null
  },
  jwtPgTypeIdentifier: '_0x0.jwt_token', 
  pluginHook
}))

// start express server
const server = app.listen(process.env.PORT, () => {
  const address = server.address();
  if (typeof address !== 'string') {
    const href = `http://localhost:${address.port}/graphiql}`;
    console.log(`PostGraphiQL available at ${href} 🚀`);
  } else {
    console.log(`PostGraphile listening on ${address} 🚀`);
  }
});