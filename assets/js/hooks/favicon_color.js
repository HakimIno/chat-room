const FaviconColor = {
  mounted() {
    console.log("FaviconColor hook mounted");
    const img = this.el;
    const target = document.getElementById(this.el.dataset.target);

    if (!target) {
      console.error("Target element not found:", this.el.dataset.target);
      return;
    }

    img.crossOrigin = "anonymous";
    
    img.onload = () => {
      console.log("Image loaded");
      const canvas = document.createElement('canvas');
      const context = canvas.getContext('2d');
      canvas.width = img.width;
      canvas.height = img.height;
      context.drawImage(img, 0, 0);

      try {
        const data = context.getImageData(0, 0, 1, 1).data;
        const [r, g, b] = data;
        const color = `rgb(${r}, ${g}, ${b}, 0.1)`;
        console.log("Extracted color:", color);
        target.style.backgroundColor = color;
        target.style.backdropFilter = 'blur(8px)';
      } catch (e) {
        console.error('Error getting favicon color:', e);
      }
    };
  }
};

export default FaviconColor; 