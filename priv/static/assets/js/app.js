const Hooks = {}

Hooks.LocalTime = {
  mounted()  { this.format() },
  updated()  { this.format() },
  format() {
    const d = new Date(this.el.dataset.utc)
    this.el.textContent = d.toLocaleString([], {day: "2-digit", month: "short", hour: "numeric", minute: "2-digit"})
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks
})

liveSocket.connect()
window.liveSocket = liveSocket
