import { ArrowDownUp, ChartNoAxesColumn, Check, createIcons, Crown, Database, FileVideo, FolderOpen, Info, Moon, Pencil, Settings, Skull, Sun, Tag, Trash2, Unplug, Upload, X } from "lucide"

const icons = { ArrowDownUp, ChartNoAxesColumn, Check, Crown, Database, FileVideo, FolderOpen, Info, Moon, Pencil, Settings, Skull, Sun, Tag, Trash2, Unplug, Upload, X }

export function renderIcons(root = document) {
  createIcons({ icons, root })
}
