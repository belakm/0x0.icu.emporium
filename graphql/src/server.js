import * as http from 'http';
import { postgraphile, makePluginHook } from 'postgraphile'
import makeAllowedOriginTweak from './plugins/cors'

const pluginHook = makePluginHook([
  makeAllowedOriginTweak('localhost'),
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