import { spawn } from "node:child_process"
import { once } from "node:events"
import readline from "node:readline"

export function parseReadyLine(line) {
  try {
    const event = JSON.parse(line)
    if (event.event !== "ready" || !Number.isInteger(event.port)) return null
    if (event.port < 1 || event.port > 65_535) return null
    return { event: "ready", port: event.port }
  } catch {
    return null
  }
}

export function buildSidecarArgs({ projectPath, parentPid }) {
  if (!projectPath) throw new Error("project path is required")
  if (!Number.isInteger(parentPid) || parentPid <= 1) throw new Error("parent PID must be greater than 1")

  return [
    "--quiet",
    "webui",
    "--port",
    "0",
    "--parent-pid",
    String(parentPid),
    projectPath
  ]
}

export class Sidecar {
  constructor({ timeoutMs = 30_000, stopTimeoutMs = 5_000, fetchImplementation = fetch } = {}) {
    this.timeoutMs = timeoutMs
    this.stopTimeoutMs = stopTimeoutMs
    this.fetchImplementation = fetchImplementation
    this.child = null
    this.exitPromise = null
    this.stdout = ""
    this.stderr = ""
  }

  get running() {
    return this.child !== null && this.child.exitCode === null
  }

  async start({ executable, prefixArgs = [], projectPath, parentPid = process.pid, env = process.env }) {
    if (this.running) throw new Error("sidecar is already running")

    const args = [...prefixArgs, ...buildSidecarArgs({ projectPath, parentPid })]

    this.stdout = ""
    this.stderr = ""
    this.child = spawn(executable, args, {
      env,
      stdio: ["ignore", "pipe", "pipe"]
    })
    this.exitPromise = once(this.child, "exit")
    this.child.stderr.setEncoding("utf8")
    this.child.stderr.on("data", chunk => {
      this.stderr = `${this.stderr}${chunk}`.slice(-16_384)
    })

    try {
      const ready = await this.waitUntilReady()
      const origin = `http://127.0.0.1:${ready.port}`
      await this.verifyHealth(origin)
      return { ...ready, origin }
    } catch (error) {
      await this.stop()
      throw error
    }
  }

  async stop() {
    const child = this.child
    const exitPromise = this.exitPromise
    if (!child) return

    if (child.exitCode === null) {
      child.kill("SIGTERM")
      const exited = await settleWithin(exitPromise, this.stopTimeoutMs)
      if (!exited && child.exitCode === null) {
        child.kill("SIGKILL")
        await exitPromise
      }
    }

    this.child = null
    this.exitPromise = null
  }

  waitUntilReady() {
    return new Promise((resolve, reject) => {
      const lines = readline.createInterface({ input: this.child.stdout })
      const timeout = setTimeout(() => {
        cleanup()
        reject(new Error(`sidecar did not become ready within ${this.timeoutMs}ms${this.errorDetails()}`))
      }, this.timeoutMs)

      const cleanup = () => {
        clearTimeout(timeout)
        lines.removeListener("line", onLine)
        this.child.removeListener("error", onError)
        this.child.removeListener("exit", onExit)
        lines.close()
      }
      const onLine = line => {
        const ready = parseReadyLine(line)
        if (!ready) {
          this.stdout = `${this.stdout}${line}\n`.slice(-16_384)
          return
        }
        cleanup()
        resolve(ready)
      }
      const onError = error => {
        cleanup()
        reject(new Error(`failed to launch sidecar: ${error.message}`))
      }
      const onExit = (code, signal) => {
        cleanup()
        reject(new Error(`sidecar exited before readiness (code=${code}, signal=${signal})${this.errorDetails()}`))
      }

      lines.on("line", onLine)
      this.child.once("error", onError)
      this.child.once("exit", onExit)
    })
  }

  async verifyHealth(origin) {
    let response
    try {
      response = await this.fetchImplementation(`${origin}/api/health`, {
        signal: AbortSignal.timeout(this.timeoutMs)
      })
    } catch (error) {
      throw new Error(`sidecar health check failed: ${error.message}${this.errorDetails()}`)
    }

    if (!response.ok) {
      throw new Error(`sidecar health check returned HTTP ${response.status}${this.errorDetails()}`)
    }

    const body = await response.json()
    if (body.status !== "ok") {
      throw new Error(`sidecar health response was not ok${this.errorDetails()}`)
    }
  }

  errorDetails() {
    const details = [this.stdout, this.stderr].map(output => output.trim()).filter(Boolean).join("\n")
    return details ? `: ${details}` : ""
  }
}

function settleWithin(promise, timeoutMs) {
  return new Promise(resolve => {
    const timeout = setTimeout(() => resolve(false), timeoutMs)
    promise.then(
      () => {
        clearTimeout(timeout)
        resolve(true)
      },
      () => {
        clearTimeout(timeout)
        resolve(true)
      }
    )
  })
}
