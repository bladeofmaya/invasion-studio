import { isAllowedAppUrl } from "./security.js"

export function configurePermissions(session, appContents, port) {
  const allowed = (contents, permission, url, details) =>
    permission === "fullscreen" &&
    contents === appContents &&
    !contents.isDestroyed() &&
    details.isMainFrame === true &&
    isAllowedAppUrl(contents.getURL(), port) &&
    isAllowedAppUrl(url, port)

  session.setPermissionCheckHandler((contents, permission, origin, details) =>
    allowed(contents, permission, origin, details))
  session.setPermissionRequestHandler((contents, permission, callback, details) =>
    callback(allowed(contents, permission, details.requestingUrl, details)))
}
