import { stat } from "node:fs/promises"
import path from "node:path"

export async function selectProject(dialog, mode) {
  if (!['open', 'create'].includes(mode)) throw new Error(`unsupported project selection mode: ${mode}`)

  const create = mode === 'create'
  const result = await dialog.showOpenDialog({
    title: create ? "Create or select a project folder" : "Open an Invasion Studio project",
    buttonLabel: create ? "Use this folder" : "Open project",
    properties: create ? ["openDirectory", "createDirectory"] : ["openDirectory"]
  })
  return result.canceled ? null : result.filePaths[0] ?? null
}

export async function validateProjectPath(candidate) {
  if (typeof candidate !== "string" || candidate.trim() === "") return null
  const resolved = path.resolve(candidate)
  try {
    return (await stat(resolved)).isDirectory() ? resolved : null
  } catch (error) {
    if (error.code === "ENOENT" || error.code === "ENOTDIR") return null
    throw error
  }
}
