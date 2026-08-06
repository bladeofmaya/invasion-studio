import { mkdir, readFile, rename, stat, writeFile } from "node:fs/promises"
import path from "node:path"

export class RecentProjects {
  constructor({ filePath, limit = 10, clock = () => new Date() }) {
    this.filePath = filePath
    this.limit = limit
    this.clock = clock
  }

  async list() {
    const projects = await this.read()
    const existing = []

    for (const project of projects) {
      const projectPath = await directoryPath(project.path)
      if (!projectPath) continue
      existing.push({
        path: projectPath,
        name: path.basename(projectPath),
        lastOpenedAt: project.lastOpenedAt
      })
    }

    const limited = existing
      .sort((left, right) => right.lastOpenedAt.localeCompare(left.lastOpenedAt))
      .slice(0, this.limit)
    await this.write(limited.map(({ path: projectPath, lastOpenedAt }) => ({ path: projectPath, lastOpenedAt })))
    return limited
  }

  async add(projectPath) {
    const validPath = await directoryPath(projectPath)
    if (!validPath) throw new Error("project folder does not exist")

    const projects = (await this.read()).filter(project => path.resolve(project.path) !== validPath)
    projects.unshift({ path: validPath, lastOpenedAt: this.clock().toISOString() })
    await this.write(projects.slice(0, this.limit))
  }

  async read() {
    try {
      const value = JSON.parse(await readFile(this.filePath, "utf8"))
      return Array.isArray(value) ? value.filter(validRecord) : []
    } catch (error) {
      if (error.code === "ENOENT" || error instanceof SyntaxError) return []
      throw error
    }
  }

  async write(projects) {
    await mkdir(path.dirname(this.filePath), { recursive: true })
    const temporaryPath = `${this.filePath}.tmp`
    await writeFile(temporaryPath, `${JSON.stringify(projects, null, 2)}\n`, { mode: 0o600 })
    await rename(temporaryPath, this.filePath)
  }
}

async function directoryPath(candidate) {
  if (typeof candidate !== "string" || candidate.trim() === "") return null
  const resolved = path.resolve(candidate)
  try {
    return (await stat(resolved)).isDirectory() ? resolved : null
  } catch (error) {
    if (error.code === "ENOENT" || error.code === "ENOTDIR") return null
    throw error
  }
}

function validRecord(record) {
  return record && typeof record.path === "string" && typeof record.lastOpenedAt === "string"
}
