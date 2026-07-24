import { Application } from "@hotwired/stimulus"
import RouterController from "../public/controllers/router_controller.js"
import VideoPlayerController from "../public/controllers/video_player_controller.js"
import EditorController from "../public/controllers/editor_controller.js"
import ClipListController from "../public/controllers/clip_list_controller.js"
import NavigationController from "../public/controllers/navigation_controller.js"
import GroupManagerController from "../public/controllers/group_manager_controller.js"

const application = Application.start()
application.register("router", RouterController)
application.register("video-player", VideoPlayerController)
application.register("editor", EditorController)
application.register("clip-list", ClipListController)
application.register("navigation", NavigationController)
application.register("group-manager", GroupManagerController)
