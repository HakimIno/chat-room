let Hooks = {}

Hooks.ScrollToBottom = {
  mounted() {
    this.scrollToBottom()
    this.handleScrolling()
  },

  updated() {
    this.handleScrolling()
  },

  handleScrolling() {
    // Check if we're near bottom before scrolling
    const container = this.el
    const atBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 100

    // Only auto-scroll if we're already near the bottom
    if (atBottom) {
      this.scrollToBottom()
    }

    // Handle mobile keyboard
    if (window.visualViewport) {
      window.visualViewport.addEventListener('resize', () => {
        if (window.visualViewport.height < window.innerHeight) {
          // Keyboard is visible
          this.scrollToBottom()
        }
      })
    }
  },

  scrollToBottom() {
    const messagesEnd = document.getElementById("messages-end")
    if (messagesEnd) {
      setTimeout(() => {
        messagesEnd.scrollIntoView({ behavior: "smooth" })
      }, 100)
    }
  }
}

export default Hooks 