// Loaded only by the source development launcher; production does not poll.
(() => {
  let revision
  let candidate
  async function poll() {
    try {
      const response = await fetch('/__dev/revision', { cache: 'no-store' })
      if (response.ok) {
        const next = await response.text()
        if (revision === undefined) revision = next
        // Wait for builds/template saves to settle before reloading.
        if (next !== revision && next === candidate) location.reload()
        candidate = next
      }
    } catch { /* The Ruby backend may be restarting. Keep polling. */ }
    setTimeout(poll, 700)
  }
  void poll()
})()
