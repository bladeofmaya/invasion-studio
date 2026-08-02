import { ArrowDownUp, ChartNoAxesColumn, Check, ChevronsDown, ChevronsUp, createIcons, Crown, Database, FileVideo, FileVideoCamera, FolderOpen, Info, ListVideo, Moon, Pencil, Settings, Skull, Sun, Tag, Trash2, Unplug, Upload, X } from "lucide"

const icons = { ArrowDownUp, ChartNoAxesColumn, Check, ChevronsDown, ChevronsUp, Crown, Database, FileVideo, FileVideoCamera, FolderOpen, Info, ListVideo, Moon, Pencil, Settings, Skull, Sun, Tag, Trash2, Unplug, Upload, X }

export function renderIcons(root = document) {
  createIcons({ icons, root })
}
