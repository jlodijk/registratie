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
    this.setLang()
    this.setupCalendar()
    this.bindEvents()
    this.syncFromHidden()
  },
  updated() {
    this.assignElements()
    this.setLang()
    this.setupCalendar()
    this.syncFromHidden()
  },
  destroyed() {
    this.unbindEvents()
    this.destroyCalendar()
  },
  assignElements() {
    this.displayInput = this.el.querySelector("[data-role='display']")
    this.hiddenInput = this.el.querySelector("[data-role='hidden']")
    this.trigger = this.el.querySelector("[data-role='trigger']")
  },
  setLang() {
    if (this.displayInput) this.displayInput.lang = "nl"
    if (this.hiddenInput) this.hiddenInput.lang = "nl"
  },
  bindEvents() {
    this.handleDisplayInput = () => this.syncFromDisplay()
    this.handleHiddenInput = () => this.syncFromHidden()
    this.handleTriggerClick = event => {
      event.preventDefault()
      this.toggleCalendar()
    }
    this.handleOutside = event => {
      if (!this.calendar) return
      if (this.calendar.contains(event.target)) return
      if (this.el.contains(event.target)) return
      this.hideCalendar()
    }
    this.handleEsc = event => {
      if (event.key === "Escape") this.hideCalendar()
    }

    this.displayInput?.addEventListener("input", this.handleDisplayInput)
    this.displayInput?.addEventListener("blur", this.handleDisplayInput)
    this.hiddenInput?.addEventListener("input", this.handleHiddenInput)
    this.trigger?.addEventListener("click", this.handleTriggerClick)
    document.addEventListener("click", this.handleOutside)
    document.addEventListener("keydown", this.handleEsc)
  },
  unbindEvents() {
    this.displayInput?.removeEventListener("input", this.handleDisplayInput)
    this.displayInput?.removeEventListener("blur", this.handleDisplayInput)
    this.hiddenInput?.removeEventListener("input", this.handleHiddenInput)
    this.trigger?.removeEventListener("click", this.handleTriggerClick)
    document.removeEventListener("click", this.handleOutside)
    document.removeEventListener("keydown", this.handleEsc)
  },
  syncFromHidden() {
    if (!this.hiddenInput || !this.displayInput) return
    this.displayInput.value = isoToEu(this.hiddenInput.value)
  },
  syncFromDisplay() {
    if (!this.hiddenInput || !this.displayInput) return
    const iso = euToIso(this.displayInput.value)
    this.hiddenInput.value = iso
  },
  setupCalendar() {
    if (this.calendar || !this.el) return
    const cal = document.createElement("div")
    cal.className = "absolute z-50 mt-2 w-64 rounded-lg border border-zinc-300 bg-white p-3 shadow-lg"
    cal.style.display = "none"
    cal.setAttribute("role", "dialog")
    cal.setAttribute("aria-label", "Kalender")
    cal.innerHTML = `
      <div class="flex items-center justify-between mb-2 text-sm font-semibold text-zinc-700">
        <button type="button" data-cal-prev class="px-2 py-1 rounded hover:bg-zinc-100">&lt;</button>
        <span data-cal-month></span>
        <button type="button" data-cal-next class="px-2 py-1 rounded hover:bg-zinc-100">&gt;</button>
      </div>
      <div class="grid grid-cols-7 text-center text-xs font-semibold text-zinc-600 mb-1">
        ${DAYS_NL.map(d => `<div>${d}</div>`).join("")}
      </div>
      <div data-cal-grid class="grid grid-cols-7 gap-1 text-sm"></div>
    `
    this.el.style.position = "relative"
    this.el.appendChild(cal)
    this.calendar = cal
    this.monthEl = cal.querySelector("[data-cal-month]")
    this.gridEl = cal.querySelector("[data-cal-grid]")
    cal.querySelector("[data-cal-prev]").addEventListener("click", () => this.changeMonth(-1))
    cal.querySelector("[data-cal-next]").addEventListener("click", () => this.changeMonth(1))
    this.currentDate = this.initialDate()
    this.renderCalendar()
  },
  destroyCalendar() {
    if (this.calendar) {
      this.calendar.remove()
      this.calendar = null
    }
  },
  initialDate() {
    const iso = this.hiddenInput?.value
    const parsed = iso && iso.match(/^(\d{4})-(\d{2})-(\d{2})$/)
    if (parsed) {
      const [, y, m, d] = parsed
      return new Date(Date.UTC(parseInt(y, 10), parseInt(m, 10) - 1, parseInt(d, 10)))
    }
    return new Date()
  },
  toggleCalendar() {
    if (!this.calendar) return
    const isVisible = this.calendar.style.display === "block"
    if (isVisible) {
      this.hideCalendar()
    } else {
      this.currentDate = this.initialDate()
      this.renderCalendar()
      this.calendar.style.display = "block"
    }
  },
  hideCalendar() {
    if (this.calendar) this.calendar.style.display = "none"
  },
  changeMonth(delta) {
    const d = this.currentDate
    this.currentDate = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + delta, 1))
    this.renderCalendar()
  },
  renderCalendar() {
    if (!this.calendar) return
    const year = this.currentDate.getUTCFullYear()
    const month = this.currentDate.getUTCMonth()
    this.monthEl.textContent = `${MONTHS_NL[month]} ${year}`

    const first = new Date(Date.UTC(year, month, 1))
    const startOffset = (first.getUTCDay() + 6) % 7 // Monday = 0
    const daysInMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate()

    const cells = []
    for (let i = 0; i < startOffset; i++) cells.push("")
    for (let day = 1; day <= daysInMonth; day++) cells.push(day)

    this.gridEl.innerHTML = ""
    cells.forEach(value => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "h-8 w-8 rounded text-sm hover:bg-zinc-100 focus:outline-none focus:ring-2 focus:ring-zinc-400"
      if (value === "") {
        btn.disabled = true
        btn.classList.add("cursor-default")
        btn.textContent = ""
      } else {
        btn.textContent = value
        btn.addEventListener("click", () => this.selectDate(year, month, value))
      }
      this.gridEl.appendChild(btn)
    })
  },
  selectDate(year, month, day) {
    const iso = `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`
    this.hiddenInput.value = iso
    this.displayInput.value = isoToEu(iso)
    this.hideCalendar()
    this.hiddenInput.dispatchEvent(new Event("input", {bubbles: true}))
    this.displayInput.dispatchEvent(new Event("input", {bubbles: true}))
  }
}

const MONTHS_NL = ["JAN", "FEB", "MRT", "APR", "MEI", "JUN", "JUL", "AUG", "SEP", "OKT", "NOV", "DEC"]
const DAYS_NL = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"]

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
