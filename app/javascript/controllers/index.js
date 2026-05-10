import { application } from "./application"

import HelloController from "./hello_controller"
application.register("hello", HelloController)

import ChartZoomController from "./chart_zoom_controller"
application.register("chart-zoom", ChartZoomController)
