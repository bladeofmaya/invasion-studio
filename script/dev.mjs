import { spawn, spawnSync } from "node:child_process"
import { existsSync, mkdirSync, readdirSync, statSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const args = process.argv.slice(2)
const usage = "Usage: bin/dev [--browser] [PROJECT] | console | icon"
if (args.includes("--help") || args.includes("-h")) {
  console.log(`${usage}\nWatches source files; no packaging, dependency installation or tests.\nDefault project: tmp/dev-project. Browser port: STUDIO_DEV_PORT (default 4567).`)
  process.exit(0)
}
const browser = args.includes("--browser")
const projects = args.filter(arg => arg !== "--browser")
if (projects.length > 1 || projects.some(arg => arg.startsWith("-"))) {
  console.error(usage)
  process.exit(2)
}
const project = projects.length
  ? path.resolve(process.env.STUDIO_CALLER_DIR || root, projects[0])
  : path.join(root, "tmp/dev-project")
if (!projects.length) mkdirSync(project, { recursive: true })
if (!existsSync(project) || !statSync(project).isDirectory()) throw new Error(`Project directory does not exist: ${project}`)
for (const file of ["node_modules/.bin/esbuild", "node_modules/.bin/tailwindcss", ...(!browser ? ["desktop/electron/node_modules/.bin/electron"] : [])]) {
  if (!existsSync(path.join(root, file))) throw new Error(`Missing ${file}. Run bin/setup first.`)
}
const built = spawnSync("npm", ["run", "build"], { cwd: root, stdio: "inherit" })
if (built.status !== 0) process.exit(built.status || 1)

const children = new Set()
const expectedExits = new WeakSet()
let stopping = false
let application
let timer
const env = {
  ...process.env,
  APP_ENV: "development",
  INVASION_STUDIO_DEV: "1",
  INVASION_STUDIO_SIDECAR: path.join(root, "bin/invasion-studio"),
  INVASION_STUDIO_PROJECT: project
}
const port = process.env.STUDIO_DEV_PORT || "4567"
if (!/^\d+$/.test(port) || Number(port) < 1 || Number(port) > 65535) throw new Error("Invalid STUDIO_DEV_PORT")
function start(command, argv) {
  const child = spawn(command, argv, { cwd: root, env, stdio: "inherit", detached: process.platform !== "win32" })
  children.add(child)
  child.once("error", error => { console.error(error.message); void shutdown(1) })
  child.once("exit", code => {
    children.delete(child)
    if (!expectedExits.has(child) && !stopping) void shutdown(child === application ? (code || 0) : (code || 1))
  })
  return child
}
function signal(child, name) {
  try {
    if (process.platform === "win32") child.kill(name)
    else process.kill(-child.pid, name)
  } catch (error) {
    if (error.code !== "ESRCH") console.error(error.message)
  }
}
async function stop(child) {
  if (!child || child.exitCode !== null || child.signalCode !== null) return
  expectedExits.add(child)
  await new Promise(resolve => {
    const timeout = setTimeout(() => { signal(child, "SIGKILL"); resolve() }, 6000)
    child.once("exit", () => { clearTimeout(timeout); resolve() })
    signal(child, "SIGTERM")
  })
}
async function shutdown(code) {
  if (stopping) return
  stopping = true
  clearInterval(timer)
  await Promise.all([...children].map(stop))
  process.exit(code)
}
function startApplication() {
  return browser
    ? start("ruby", ["bin/invasion-studio", "webui", "--port", port, project])
    : start(path.join(root, "desktop/electron/node_modules/.bin/electron"), ["desktop/electron"])
}
// Poll source metadata: portable across filesystems and handles atomic editor saves.
function sourceStamp() {
  const files = []
  function scan(directory, accept) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const file = path.join(directory, entry.name)
      if (entry.isDirectory()) scan(file, accept)
      else if (accept(file)) {
        const stat = statSync(file)
        files.push(`${file}:${stat.mtimeMs}:${stat.size}`)
      }
    }
  }
  scan(path.join(root, "lib"), file => file.endsWith(".rb"))
  if (!browser) scan(path.join(root, "desktop/electron/src"), () => true)
  const cli = statSync(path.join(root, "bin/invasion-studio"))
  files.push(`cli:${cli.mtimeMs}:${cli.size}`)
  return files.sort().join("\n")
}
start(path.join(root, "node_modules/.bin/tailwindcss"), ["-i", "lib/invasion_studio/webui/frontend/app.css", "-o", "lib/invasion_studio/webui/public/assets/app.css", "--watch=always"])
start(path.join(root, "node_modules/.bin/esbuild"), ["lib/invasion_studio/webui/frontend/app.js", "--bundle", "--format=esm", "--outdir=lib/invasion_studio/webui/public/assets", "--watch=forever"])
application = startApplication()
console.log(`Development project: ${project}`)
if (browser) console.log(`Open http://127.0.0.1:${port} in your browser.`)
console.log("UI changes reload the page. Ruby/Electron changes restart the app. Ctrl+C stops all processes.")
let stamp = sourceStamp()
let restarting = false
// Wait for a stable source snapshot to debounce saves.
let pendingStamp = stamp
timer = setInterval(async () => {
  if (stopping || restarting) return
  let next
  try { next = sourceStamp() } catch { return }
  if (next !== pendingStamp) { pendingStamp = next; return }
  if (next === stamp) return
  stamp = next
  restarting = true
  console.log("Source changed; restarting development app…")
  await stop(application)
  if (!stopping) application = startApplication()
  restarting = false
}, 500)
process.on("SIGINT", () => void shutdown(0))
process.on("SIGTERM", () => void shutdown(0))
