import { Controller } from "@hotwired/stimulus"

// Auto-dismiss flash messages after 5 seconds with fade-out
export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => this.dismiss(), 5000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  remove() {
    this.dismiss()
  }

  dismiss() {
    this.element.style.transition = "opacity 0.4s ease"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 400)
  }
}
