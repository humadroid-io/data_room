import { Controller } from "@hotwired/stimulus"

// Renders dynamic add/remove rows for a Rails `accepts_nested_attributes_for`
// association. Pair with a server-rendered template (Stimulus target name
// "template") whose innerHTML contains a single fields_for row whose name
// indices are placeholder `NEW_RECORD`. On `add` we clone the template,
// substitute a unique index, and append into `target`. On `remove` we either
// hide an existing record and flip its `_destroy` hidden input to "1", or
// drop a never-persisted row from the DOM outright.

export default class extends Controller {
  static targets = ["target", "template"]

  add(event) {
    event.preventDefault()
    const index = new Date().getTime()
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, index)
    this.targetTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-nested-form-row]")
    if (!row) return

    const destroyInput = row.querySelector("input[name*='_destroy']")
    if (destroyInput) {
      destroyInput.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }
  }
}
