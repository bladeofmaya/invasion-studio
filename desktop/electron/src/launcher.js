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
    const row = document.createElement("div")
    row.className = "recent-project-row"
    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "remove-project"
    remove.textContent = "×"
    remove.title = "Remove from recent projects — files are kept"
    remove.setAttribute("aria-label", `Remove ${project.name} from recent projects`)
    remove.addEventListener("click", () => removeProject(project))
    row.append(button, remove)
    recentProjects.append(row)
  }
}

async function removeProject(project) {
  setDisabled(true)
  showStatus("")
  try {
    const projects = await desktop.removeRecentProject(project.path)
    renderProjects(projects)
    showStatus(`${project.name} removed from recent projects. Files are unchanged.`)
    setDisabled(false)
    const nextButton = recentProjects.querySelector("button") || openButton
    nextButton.focus()
  } catch {
    showStatus("Could not remove the project from the list. Please try again.")
  } finally {
    setDisabled(false)
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
