import http from "node:http"

if (process.env.FAKE_SIDECAR_MODE === "failure") {
  process.stdout.write("Error: database migration mismatch\n")
  process.exit(1)
} else if (process.env.FAKE_SIDECAR_MODE === "silent") {
  setInterval(() => {}, 1_000)
} else {
  const server = http.createServer((request, response) => {
    if (request.url === "/api/health") {
      response.writeHead(200, { "content-type": "application/json" })
      response.end(JSON.stringify({ status: "ok" }))
      return
    }

    response.writeHead(404)
    response.end()
  })

  server.listen(0, "127.0.0.1", () => {
    const { port } = server.address()
    process.stdout.write(`sidecar diagnostic\n`)
    process.stdout.write(`${JSON.stringify({ event: "ready", port })}\n`)
  })

  process.on("SIGTERM", () => server.close(() => process.exit(0)))
}
