// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const Hooks = {}

const HelpModal = {
  modal: null,
  titleEl: null,
  bodyEl: null,
  init() {
    this.modal = document.getElementById("help-modal")
    if (!this.modal) return
    this.titleEl = this.modal.querySelector("[data-help-title]")
    this.bodyEl = this.modal.querySelector("[data-help-body]")
    const closeButtons = this.modal.querySelectorAll("[data-help-close]")
    closeButtons.forEach(btn => btn.addEventListener("click", () => this.hide()))
    this.modal.addEventListener("click", event => {
      if (event.target === this.modal) {
        this.hide()
      }
    })
  },
  show(title, text) {
    if (!this.modal) return
    this.titleEl.textContent = title || "Help"
    this.bodyEl.textContent = text || ""
    this.modal.classList.remove("hidden")
  },
  hide() {
    this.modal?.classList.add("hidden")
  }
}

Hooks.FieldHelp = {
  mounted() {
    HelpModal.init()
    this.handleClick = event => {
      event.preventDefault()
      HelpModal.show(this.el.dataset.helpTitle, this.el.dataset.helpText)
    }
    this.el.addEventListener("click", this.handleClick)
  },
  destroyed() {
    this.el.removeEventListener("click", this.handleClick)
  }
}

Hooks.EuDatePicker = {
  mounted() {
    this.assignElements()
    this.bindEvents()
    this.syncFromHidden()
  },
  updated() {
    this.assignElements()
    this.syncFromHidden()
  },
  destroyed() {
    this.unbindEvents()
  },
  assignElements() {
    this.displayInput = this.el.querySelector("[data-role='display']")
    this.hiddenInput = this.el.querySelector("[data-role='hidden']")
    this.trigger = this.el.querySelector("[data-role='trigger']")
  },
  bindEvents() {
    this.handleDisplayInput = () => this.syncFromDisplay()
    this.handleHiddenInput = () => this.syncFromHidden()
    this.handleTriggerClick = event => {
      event.preventDefault()
      if (this.hiddenInput && typeof this.hiddenInput.showPicker === "function") {
        this.hiddenInput.showPicker()
      } else {
        this.hiddenInput?.focus()
      }
    }

    this.displayInput?.addEventListener("input", this.handleDisplayInput)
    this.displayInput?.addEventListener("blur", this.handleDisplayInput)
    this.hiddenInput?.addEventListener("input", this.handleHiddenInput)
    this.trigger?.addEventListener("click", this.handleTriggerClick)
  },
  unbindEvents() {
    this.displayInput?.removeEventListener("input", this.handleDisplayInput)
    this.displayInput?.removeEventListener("blur", this.handleDisplayInput)
    this.hiddenInput?.removeEventListener("input", this.handleHiddenInput)
    this.trigger?.removeEventListener("click", this.handleTriggerClick)
  },
  syncFromHidden() {
    if (!this.hiddenInput || !this.displayInput) return
    this.displayInput.value = isoToEu(this.hiddenInput.value)
  },
  syncFromDisplay() {
    if (!this.hiddenInput || !this.displayInput) return
    const iso = euToIso(this.displayInput.value)
    this.hiddenInput.value = iso
  }
}

function isoToEu(value) {
  if (!value) return ""
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (!match) return ""
  const [, year, month, day] = match
  return `${day}-${month}-${year}`
}

function euToIso(value) {
  if (!value) return ""
  const match = value.match(/^(\d{1,2})-(\d{1,2})-(\d{4})$/)
  if (!match) return ""
  const [, day, month, year] = match
  const dayNum = parseInt(day, 10)
  const monthNum = parseInt(month, 10)
  const yearNum = parseInt(year, 10)
  if (!validDateParts(dayNum, monthNum, yearNum)) return ""

  const date = new Date(Date.UTC(yearNum, monthNum - 1, dayNum))
  if (
    date.getUTCFullYear() !== yearNum ||
    date.getUTCMonth() !== monthNum - 1 ||
    date.getUTCDate() !== dayNum
  ) {
    return ""
  }

  return `${yearNum}-${String(monthNum).padStart(2, "0")}-${String(dayNum).padStart(2, "0")}`
}

function validDateParts(day, month, year) {
  return (
    Number.isInteger(day) &&
    Number.isInteger(month) &&
    Number.isInteger(year) &&
    day >= 1 &&
    day <= 31 &&
    month >= 1 &&
    month <= 12 &&
    year >= 1900 &&
    year <= 9999
  )
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => {
  topbar.hide()
  HelpModal.init()
})
window.addEventListener("DOMContentLoaded", () => HelpModal.init())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
