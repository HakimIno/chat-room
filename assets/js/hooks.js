let Hooks = {}

Hooks.ScrollToBottom = {
  mounted() {
    this.el.scrollTop = this.el.scrollHeight
    this.handleEvent("new-message", () => {
      this.el.scrollTop = this.el.scrollHeight
    })
  }
}

Hooks.RoomAuth = {
  mounted() {
    // เช็คสถานะการ auth เมื่อโหลดหน้า
    const roomId = this.el.dataset.roomId
    const isAuthenticated = sessionStorage.getItem(`room_auth_${roomId}`) === "true"
    
    if (isAuthenticated) {
      this.pushEvent("auth_status", { authenticated: true, room_id: roomId })
    }

    // รับ event จาก LiveView
    window.addEventListener(`phx:save_auth`, (e) => {
      const { room_id } = e.detail
      sessionStorage.setItem(`room_auth_${room_id}`, "true")
    })
  }
}

export default Hooks