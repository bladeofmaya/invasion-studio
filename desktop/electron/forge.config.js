import { readFileSync } from "node:fs"
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
const extraResource = [sidecar, path.join(path.dirname(sidecar), "backend-notices"), path.join(path.dirname(sidecar), "dependencies.json"), ...["MIT-LICENSE", "THIRD_PARTY_LICENSES.md"].map(file => path.join(repositoryRoot, file))]
const mediaModules = JSON.parse(readFileSync(path.join(repositoryRoot, "desktop", "flatpak", "media-modules.json"), "utf8"))

export default {
  packagerConfig: {
    asar: true,
    executableName: "invasion-studio",
    icon: path.join(electronDirectory, "assets", "app-icon.png"),
    ignore: [/^\/(out|test|probes)(\/|$)/],
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
          baseVersion: "26.08",
          runtime: "org.freedesktop.Platform",
          runtimeVersion: "26.08",
          sdk: "org.freedesktop.Sdk",
          modules: mediaModules,
          extraFlatpakBuilderArgs: ["--force-clean", "--jobs=8", `--state-dir=${path.join(repositoryRoot, ".flatpak-builder")}`],
          finishArgs: [
            "--env=TMPDIR=/var/tmp",
            "--env=TESSDATA_PREFIX=/app/share/tessdata",
            "--share=ipc",
            "--share=network",
            "--socket=wayland",
            "--socket=fallback-x11",
            "--socket=pulseaudio",
            "--device=dri",
            "--filesystem=host"
          ],
          categories: ["AudioVideo"],
          icon: { "512x512": path.join(electronDirectory, "assets", "app-icon.png") }
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
