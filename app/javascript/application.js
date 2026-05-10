// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "@rails/activestorage"
import "@rails/actiontext"
import "@37signals/lexxy"
import "chartkick/chart.js"
import { Chart } from "chart.js"
import annotationPlugin from "chartjs-plugin-annotation"
import zoomPlugin from "chartjs-plugin-zoom"
Chart.register(annotationPlugin, zoomPlugin)
import "./controllers"
