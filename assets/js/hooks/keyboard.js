// assets/js/hooks/keyboard.js
const KeyboardHook = {
  mounted() {
    if (!window.visualViewport) return;

    const handleResize = () => {
      const currentHeight = window.visualViewport.height;
      const offset = window.innerHeight - currentHeight;
      
      if (offset > 0) {
        this.pushEvent("set_keyboard_height", { height: offset });
      } else {
        this.pushEvent("set_keyboard_height", { height: 0 });
      }
    };

    window.visualViewport.addEventListener('resize', handleResize);
    window.visualViewport.addEventListener('scroll', handleResize);

    // Cleanup
    this.destroyed = () => {
      if (!window.visualViewport) return;
      window.visualViewport.removeEventListener('resize', handleResize);
      window.visualViewport.removeEventListener('scroll', handleResize);
    };
  }
};

export default KeyboardHook;