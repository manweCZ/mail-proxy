let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken }
})

liveSocket.connect()
window.liveSocket = liveSocket
