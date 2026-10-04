import { ArrowDownUp, ChartNoAxesColumn, Check, ChevronsDown, ChevronsUp, CircleAlert, CircleCheck, CornerDownRight, createIcons, Crown, Database, Download, FileVideo, FileVideoCamera, FolderOpen, Info, ListVideo, MapPinPlus, Maximize, Moon, Package, Pause, Pencil, Play, ScanText, Scissors, Settings, Skull, Sun, Tag, Trash2, Undo2, Unplug, Upload, Video, Volume2, VolumeX, X } from "lucide"

const icons = { ArrowDownUp, ChartNoAxesColumn, Check, ChevronsDown, ChevronsUp, CircleAlert, CircleCheck, CornerDownRight, Crown, Database, Download, FileVideo, FileVideoCamera, FolderOpen, Info, ListVideo, MapPinPlus, Maximize, Moon, Package, Pause, Pencil, Play, ScanText, Scissors, Settings, Skull, Sun, Tag, Trash2, Undo2, Unplug, Upload, Video, Volume2, VolumeX, X }

export function renderIcons(root = document) {
  createIcons({ icons, root })
}
