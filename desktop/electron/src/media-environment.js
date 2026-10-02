import { accessSync, constants } from 'node:fs'

// The unpacked developer app uses system tools; the release Flatpak must never
// silently fall back to binaries outside its tested dependency set.
export function mediaEnvironment(environment, check = accessSync) {
  const result = { ...environment }
  // Puma must not treat the desktop-launched child as a systemd service.
  // In Flatpak the inherited notification socket is outside the sandbox.
  for (const key of ['NOTIFY_SOCKET', 'WATCHDOG_PID', 'WATCHDOG_USEC', 'LISTEN_PID', 'LISTEN_FDS', 'LISTEN_FDNAMES']) {
    delete result[key]
  }
  if (result.FLATPAK_ID !== 'com.bladeofmaya.InvasionStudio') return result

  for (const name of ['ffmpeg', 'ffprobe', 'tesseract']) {
    const executable = `/app/bin/${name}`
    verify(executable, constants.X_OK, check)
    result[`INVASION_STUDIO_${name.toUpperCase()}`] = executable
  }
  result.TESSDATA_PREFIX = '/app/share/tessdata'
  verify(`${result.TESSDATA_PREFIX}/eng.traineddata`, constants.R_OK, check)
  return result
}

function verify(file, mode, check) {
  try {
    check(file, mode)
  } catch {
    throw new Error(`Missing or inaccessible packaged dependency: ${file}. Reinstall Invasion Studio.`)
  }
}
