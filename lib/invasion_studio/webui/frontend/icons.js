import { ArrowDownUp, ChartNoAxesColumn, Check, ChevronsDown, ChevronsUp, CircleAlert, CircleCheck, CornerDownRight, createIcons, Crown, Database, Download, FileVideo, FileVideoCamera, FolderOpen, Info, ListVideo, MapPinPlus, Moon, Package, Pencil, ScanText, Scissors, Settings, Skull, Sun, Tag, Trash2, Undo2, Unplug, Upload, Video, X } from "lucide"

const icons = { ArrowDownUp, ChartNoAxesColumn, Check, ChevronsDown, ChevronsUp, CircleAlert, CircleCheck, CornerDownRight, Crown, Database, Download, FileVideo, FileVideoCamera, FolderOpen, Info, ListVideo, MapPinPlus, Moon, Package, Pencil, ScanText, Scissors, Settings, Skull, Sun, Tag, Trash2, Undo2, Unplug, Upload, Video, X }

export function renderIcons(root = document) {
  createIcons({ icons, root })
}
