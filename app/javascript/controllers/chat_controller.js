import { Controller } from "@hotwired/stimulus"

// Mantém a conversa do Assistente rolada para a última mensagem —
// no load e a cada bolha nova appendada pelo Turbo Stream.
export default class extends Controller {
  static targets = ["messages"]

  connect() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => this.scrollToBottom())
    this.observer.observe(this.messagesTarget, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
}
