const Uploads = {
  mounted() {
    this.handleEvent("upload_progress", ({ref, progress}) => {
      try {
        const progressBar = document.querySelector(`[data-upload-ref="${ref}"] .progress-bar`);
        if (progressBar) {
          progressBar.style.width = `${progress}%`;
          progressBar.setAttribute('aria-valuenow', progress);
        }
      } catch (error) {
        console.error("Error updating progress bar:", error);
      }
    });

    // เพิ่ม drag and drop support
    this.el.addEventListener("dragover", e => {
      e.preventDefault();
      e.stopPropagation();
      this.el.classList.add("border-blue-500");
    });

    this.el.addEventListener("dragleave", e => {
      e.preventDefault();
      e.stopPropagation();
      this.el.classList.remove("border-blue-500");
    });

    this.el.addEventListener("drop", e => {
      e.preventDefault();
      e.stopPropagation();
      this.el.classList.remove("border-blue-500");
      
      try {
        const files = Array.from(e.dataTransfer.files);
        const input = this.el.querySelector('input[type="file"]');
        
        if (input) {
          // ตรวจสอบจำนวนไฟล์ที่มีอยู่แล้ว
          const currentFiles = input.files ? Array.from(input.files) : [];
          const totalFiles = currentFiles.length + files.length;
          
          if (totalFiles > 6) {
            alert("สามารถอัพโหลดได้สูงสุด 6 รูป");
            return;
          }

          const dataTransfer = new DataTransfer();
          
          // เพิ่มไฟล์ที่มีอยู่แล้ว
          currentFiles.forEach(file => dataTransfer.items.add(file));
          
          // เพิ่มไฟล์ใหม่
          files.forEach(file => {
            if (file.type.startsWith('image/')) {
              console.log("Adding image:", file.name, file.type);
              dataTransfer.items.add(file);
            } else {
              console.warn("Skipping non-image file:", file.name);
            }
          });

          input.files = dataTransfer.files;
          input.dispatchEvent(new Event('change', { bubbles: true }));
        }
      } catch (error) {
        console.error("Error handling file drop:", error);
      }
    });
  }
};

export default Uploads; 