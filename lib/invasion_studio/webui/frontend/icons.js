import { ArrowDownUp, Check, createIcons, Crown, FileVideo, FolderOpen, Info, Moon, Pencil, Settings, Skull, Sun, Tag, Trash2, Unplug, Upload, X } from "lucide"

const icons = { ArrowDownUp, Check, Crown, FileVideo, FolderOpen, Info, Moon, Pencil, Settings, Skull, Sun, Tag, Trash2, Unplug, Upload, X }

export function renderIcons(root = document) {
  createIcons({ icons, root })
}
