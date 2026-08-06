import { existsSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import { FuseV1Options, FuseVersion } from "@electron/fuses"
import { FusesPlugin } from "@electron-forge/plugin-fuses"

const electronDirectory = path.dirname(fileURLToPath(import.meta.url))
const repositoryRoot = path.resolve(electronDirectory, "..", "..")
const platformNames = { darwin: "macos", linux: "linux", win32: "windows" }
const platformKey = `${platformNames[process.platform] ?? process.platform}-${process.arch}`
const sidecarName = process.platform === "win32" ? "invasion-studio.exe" : "invasion-studio"
const sidecar = path.join(repositoryRoot, "pkg", "sidecar", platformKey, sidecarName)
const tools = path.join(repositoryRoot, "pkg", "tools", platformKey)
const extraResource = [sidecar]

if (existsSync(tools)) extraResource.push({ from: tools, to: "tools" })

export default {
  packagerConfig: {
    asar: true,
    executableName: "invasion-studio",
    icon: path.join(electronDirectory, "assets", "icon.png"),
    ignore: [/^\/(out|test)(\/|$)/],
    extraResource
  },
  rebuildConfig: {},
  makers: [
    {
      name: "@electron-forge/maker-flatpak",
      config: {
        options: {
          id: "com.bladeofmaya.InvasionStudio",
          name: "invasion-studio",
          productName: "InvasionStudio",
          genericName: "Video clip library",
          description: "Review and edit Elden Ring invasion clips",
          base: "org.electronjs.Electron2.BaseApp",
          baseVersion: "25.08",
          runtime: "org.freedesktop.Platform",
          runtimeVersion: "25.08",
          sdk: "org.freedesktop.Sdk",
          modules: [],
          finishArgs: [
            "--share=ipc",
            "--share=network",
            "--socket=wayland",
            "--socket=fallback-x11",
            "--socket=pulseaudio",
            "--device=dri",
            "--filesystem=host"
          ],
          categories: ["AudioVideo"],
          icon: path.join(electronDirectory, "assets", "icon.png")
        }
      }
    }
  ],
  plugins: [
    new FusesPlugin({
      version: FuseVersion.V1,
      [FuseV1Options.RunAsNode]: false,
      [FuseV1Options.EnableCookieEncryption]: true,
      [FuseV1Options.EnableNodeOptionsEnvironmentVariable]: false,
      [FuseV1Options.EnableNodeCliInspectArguments]: false,
      [FuseV1Options.EnableEmbeddedAsarIntegrityValidation]: true,
      [FuseV1Options.OnlyLoadAppFromAsar]: true
    })
  ]
}
