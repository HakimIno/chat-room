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
import Uploads from "./hooks/upload"
import KeyboardHook from "./hooks/keyboard"
import RoomHooks from "./hooks"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// รวม hooks ทั้งหมด
let Hooks = {
  ...RoomHooks,  // เพิ่ม hooks จากไฟล์ hooks.js
  Keyboard: KeyboardHook,
  MessageInput: {
    mounted() {
      this.el.addEventListener("submit_message", () => {
        this.el.value = "";
      });

      this.handleEvent("clear_input", () => {
        this.el.value = "";
      });
    }
  },
  ScrollChat: {
    mounted() {
      this.shouldScroll = true;
      setTimeout(() => {
        this.el.scrollTop = this.el.scrollHeight;
      }, 100);
      
      // ตรวจจับการ scroll
      this.el.addEventListener("scroll", () => {
        const bottom = this.el.scrollHeight - this.el.clientHeight;
        this.shouldScroll = Math.abs(this.el.scrollTop - bottom) < 100;
      });

      this.handleEvent("new-message", () => {
        setTimeout(() => {
          if (this.shouldScroll) {
            this.el.scrollTop = this.el.scrollHeight;
          }
        }, 100);
      });
    },
    updated() {
      setTimeout(() => {
        if (this.shouldScroll) {
          this.el.scrollTop = this.el.scrollHeight;
        }
      }, 100);
    }
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

const setAppHeight = () => {
  const doc = document.documentElement;
  doc.style.setProperty('--app-height', `${window.innerHeight}px`);
};

window.addEventListener('resize', setAppHeight);
window.addEventListener('orientationchange', setAppHeight);
setAppHeight();

