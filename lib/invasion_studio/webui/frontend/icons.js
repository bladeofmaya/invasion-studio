import { Check, createIcons, Crown, FileVideo, FolderOpen, Moon, Pencil, Skull, Sun, Tag, Trash2, Unplug, Upload, X } from "lucide"

const icons = { Check, Crown, FileVideo, FolderOpen, Moon, Pencil, Skull, Sun, Tag, Trash2, Unplug, Upload, X }

export function renderIcons(root = document) {
  createIcons({ icons, root })
}
