import { CircleX, createIcons, FileVideo, FolderOpen, Moon, Sun, Trophy, Unplug } from "lucide"

const icons = { CircleX, FileVideo, FolderOpen, Moon, Sun, Trophy, Unplug }

export function renderIcons(root = document) {
  createIcons({ icons, root })
}
