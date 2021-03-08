const http = require("http");
const { postgraphile } = require("postgraphile");   

http
  .createServer(
    postgraphile(process.env.DATABASE_URL, "_0x0", {
      watchPg: true,
      graphiql: true,
      enhanceGraphiql: true,
      retryOnInitFail: true
    })
  )
  .listen(process.env.PORT);