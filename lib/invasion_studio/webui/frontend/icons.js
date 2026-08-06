import { ArrowDownUp, ChartNoAxesColumn, Check, ChevronsDown, ChevronsUp, CircleAlert, CircleCheck, createIcons, Crown, Database, FileVideo, FileVideoCamera, FolderOpen, Info, ListVideo, Moon, Pencil, Settings, Skull, Sun, Tag, Trash2, Unplug, Upload, Video, X } from "lucide"

const icons = { ArrowDownUp, ChartNoAxesColumn, Check, ChevronsDown, ChevronsUp, CircleAlert, CircleCheck, Crown, Database, FileVideo, FileVideoCamera, FolderOpen, Info, ListVideo, Moon, Pencil, Settings, Skull, Sun, Tag, Trash2, Unplug, Upload, Video, X }

export function renderIcons(root = document) {
  createIcons({ icons, root })
}
