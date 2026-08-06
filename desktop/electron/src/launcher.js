const recentProjects = document.querySelector("#recent-projects")
const openButton = document.querySelector("#open-project")
const createButton = document.querySelector("#create-project")
const status = document.querySelector("#status")
const desktop = window.invasionStudio

if (!desktop) {
  setDisabled(true)
  showStatus("Desktop integration failed to load. Rebuild the application and try again.")
} else {
  openButton.addEventListener("click", () => select(() => desktop.openProject()))
  createButton.addEventListener("click", () => select(() => desktop.createProject()))

  loadProjects()
}

async function loadProjects() {
  try {
    renderProjects(await desktop.listProjects())
  } catch {
    showStatus("Recent projects could not be loaded.")
  }
}

function renderProjects(projects) {
  recentProjects.replaceChildren()
  if (projects.length === 0) {
    const empty = document.createElement("div")
    empty.className = "empty"
    empty.textContent = "No recent projects"
    recentProjects.append(empty)
    return
  }

  for (const project of projects) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "recent-project"
    const name = document.createElement("strong")
    name.textContent = project.name
    const projectPath = document.createElement("span")
    projectPath.textContent = project.path
    projectPath.title = project.path
    button.append(name, projectPath)
    button.addEventListener("click", () => select(() => desktop.openRecentProject(project.path)))
    recentProjects.append(button)
  }
}

async function select(action) {
  setDisabled(true)
  showStatus("")
  try {
    const selected = await action()
    if (selected) showStatus("Opening project…")
  } catch (error) {
    showStatus(error.message || "The project could not be opened.")
  } finally {
    setDisabled(false)
  }
}

function setDisabled(disabled) {
  for (const button of document.querySelectorAll("button")) button.disabled = disabled
}

function showStatus(message) {
  status.textContent = message
}
