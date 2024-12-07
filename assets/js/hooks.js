let Hooks = {}

Hooks.ScrollToBottom = {
  mounted() {
    this.el.scrollTop = this.el.scrollHeight
    this.handleEvent("new-message", () => {
      this.el.scrollTop = this.el.scrollHeight
    })
  }
}