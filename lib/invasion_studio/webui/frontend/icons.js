import { CircleX, createIcons, FileVideo, FolderOpen, Moon, Sun, Trash2, Trophy, Unplug, Upload } from "lucide"

const icons = { CircleX, FileVideo, FolderOpen, Moon, Sun, Trash2, Trophy, Unplug, Upload }

export function renderIcons(root = document) {
  createIcons({ icons, root })
}
