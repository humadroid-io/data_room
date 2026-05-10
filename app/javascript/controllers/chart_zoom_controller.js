import { Controller } from "@hotwired/stimulus"

// Wraps a Chartkick chart container with two affordances:
//   1. A "↔ Fullscreen" button that promotes the host element into a
//      viewport-sized modal and asks Chart.js to resize.
//   2. A "Reset zoom" button that calls the chartjs-plugin-zoom API.
//
// Chartkick owns the chart instance; this controller looks it up via the
// global registry by its id (passed as a Stimulus value).

export default class extends Controller {
  static targets = ["host", "reset"]
  static values  = { id: String }

  connect() {
    this.boundOnEsc = this.onEsc.bind(this)
    this.element.addEventListener("dblclick", this.onDblClick.bind(this))
    this.pollHandle = setInterval(this.attachToChart.bind(this), 100)
  }

  disconnect() {
    clearInterval(this.pollHandle)
    document.removeEventListener("keydown", this.boundOnEsc)
  }

  attachToChart() {
    if (!window.Chartkick) return
    const ck = window.Chartkick.charts[this.idValue]
    if (!ck) return
    const chart = ck.getChartObject()
    if (!chart) return

    this.chart = chart
    clearInterval(this.pollHandle)
  }

  reset() {
    if (this.chart && this.chart.resetZoom) {
      this.chart.resetZoom()
    }
  }

  toggleFullscreen() {
    this.element.classList.toggle("chart-fullscreen")
    const isFullscreen = this.element.classList.contains("chart-fullscreen")

    if (isFullscreen) {
      document.body.style.overflow = "hidden"
      document.addEventListener("keydown", this.boundOnEsc)
    } else {
      document.body.style.overflow = ""
      document.removeEventListener("keydown", this.boundOnEsc)
    }

    requestAnimationFrame(() => this.chart && this.chart.resize())
  }

  onEsc(event) {
    if (event.key === "Escape" && this.element.classList.contains("chart-fullscreen")) {
      this.toggleFullscreen()
    }
  }

  onDblClick(event) {
    // Don't double-toggle when clicking the toolbar buttons.
    if (event.target.closest("button")) return
    this.toggleFullscreen()
  }
}
