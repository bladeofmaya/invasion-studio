import assert from "node:assert/strict"
import { existsSync, readFileSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import test from "node:test"

import forgeConfig from "../forge.config.js"

const testDirectory = path.dirname(fileURLToPath(import.meta.url))
const electronDirectory = path.dirname(testDirectory)
const repositoryRoot = path.resolve(electronDirectory, "..", "..")
const packageJson = JSON.parse(readFileSync(path.join(electronDirectory, "package.json"), "utf8"))
const rubyVersion = readFileSync(path.join(repositoryRoot, "lib", "invasion_studio", "version.rb"), "utf8")
  .match(/VERSION = "([^"]+)"/)[1]

test("Electron package uses production identity and the application version", () => {
  assert.equal(packageJson.name, "invasion-studio")
  assert.equal(packageJson.productName, "Invasion Studio")
  assert.equal(packageJson.version, rubyVersion)
  assert.equal(packageJson.description, "Desktop application for reviewing and editing Elden Ring invasion clips")
})

test("production Linux icon is present", () => {
  assert.equal(existsSync(path.join(electronDirectory, "assets", "icon.png")), true)
})

test("Forge packages the production executable and Flatpak identity", () => {
  assert.equal(forgeConfig.packagerConfig.executableName, "invasion-studio")

  const flatpak = forgeConfig.makers.find(maker => maker.name === "@electron-forge/maker-flatpak")
  assert.equal(flatpak.config.options.id, "com.bladeofmaya.InvasionStudio")
  assert.equal(flatpak.config.options.name, "invasion-studio")
  assert.equal(flatpak.config.options.finishArgs.includes("--filesystem=host"), true)
})

test("future platform directories are retained in the repository", () => {
  for (const platform of ["windows-x64", "macos-x64", "macos-arm64"]) {
    assert.equal(existsSync(path.join(electronDirectory, "platforms", platform, ".gitkeep")), true)
  }
})
