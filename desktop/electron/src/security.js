export function isAllowedAppUrl(rawUrl, port) {
  try {
    const url = new URL(rawUrl)
    return url.protocol === "http:" &&
      url.hostname === "127.0.0.1" &&
      url.port === String(port) &&
      url.username === "" &&
      url.password === ""
  } catch {
    return false
  }
}

export function isAllowedExternalUrl(rawUrl) {
  try {
    return new URL(rawUrl).protocol === "https:"
  } catch {
    return false
  }
}
