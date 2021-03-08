import * as http from 'http';
import { postgraphile, makePluginHook } from 'postgraphile'
import makeAllowedOriginTweak from "./plugins/cors.js"

const pluginHook = makePluginHook([
  makeAllowedOriginTweak('http://localhost:1337'),
]);

http
  .createServer(
    postgraphile(process.env.DATABASE_URL, '_0x0', {
      watchPg: true,
      graphiql: true,
      enhanceGraphiql: true,
      retryOnInitFail: true,
      pluginHook
    })
  )
  .listen(process.env.PORT);