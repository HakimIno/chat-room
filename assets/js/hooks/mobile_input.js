const MobileInput = {
  mounted() {
    if (!this.isMobile()) return;

    const form = this.el;
    const input = form.querySelector('input[type="text"]');
    
    const handleFocus = () => {
      // เพิ่ม class เมื่อ keyboard เปิด
      form.classList.add('keyboard-open');
      
      // รอให้ keyboard เปิดเต็มที่แล้วเลื่อนหน้าจอ
      setTimeout(() => {
        window.scrollTo(0, 0);
        input.scrollIntoView({ behavior: 'smooth' });
      }, 100);
    };

    const handleBlur = () => {
      // ลบ class เมื่อ keyboard ปิด
      form.classList.remove('keyboard-open');
    };

    input.addEventListener('focus', handleFocus);
    input.addEventListener('blur', handleBlur);

    // Cleanup
    this.destroy = () => {
      input.removeEventListener('focus', handleFocus);
      input.removeEventListener('blur', handleBlur);
    };
  },

  destroyed() {
    if (this.destroy) this.destroy();
  },

  isMobile() {
    return /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
  }
};

export default MobileInput; 