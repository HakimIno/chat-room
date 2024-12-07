const StickerModal = {
  mounted() {
    this.handleShow = () => {
      this.el.classList.remove('hidden')
    }
    
    this.handleHide = () => {
      this.el.classList.add('hidden')
    }

    window.addEventListener('phx:show_sticker_modal', this.handleShow)
    window.addEventListener('phx:hide_sticker_modal', this.handleHide)
  },

  destroyed() {
    window.removeEventListener('phx:show_sticker_modal', this.handleShow)
    window.removeEventListener('phx:hide_sticker_modal', this.handleHide)
  }
}

export default StickerModal 