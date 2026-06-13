import { Application } from "@hotwired/stimulus"
import VideoPlayerController from "./controllers/video_player_controller.js"
import EditorController from "./controllers/editor_controller.js"
import ClipListController from "./controllers/clip_list_controller.js"
import NavigationController from "./controllers/navigation_controller.js"
import GroupManagerController from "./controllers/group_manager_controller.js"

const application = Application.start()
application.register("video-player", VideoPlayerController)
application.register("editor", EditorController)
application.register("clip-list", ClipListController)
application.register("navigation", NavigationController)
application.register("group-manager", GroupManagerController)
