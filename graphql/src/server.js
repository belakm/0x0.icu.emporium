const http = require("http");
const { postgraphile, makePluginHook } = require("postgraphile");   
const { makeAllowedOriginTweak } = require("./cors-plugin")

const pluginHook = makePluginHook([
  makeAllowedOriginTweak("localhost"),
]);

http
  .createServer(
    postgraphile(process.env.DATABASE_URL, "_0x0", {
      watchPg: true,
      graphiql: true,
      enhanceGraphiql: true,
      retryOnInitFail: true,
      pluginHook
    })
  )
  .listen(process.env.PORT);