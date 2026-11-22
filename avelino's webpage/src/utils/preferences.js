const THEME_KEY = "equip-campus-theme";

export function readTheme() {
  try {
    const value = localStorage.getItem(THEME_KEY);
    return ["light", "dark", "system"].includes(value) ? value : "system";
  } catch {
    return "system";
  }
}

export function saveTheme(value) {
  try {
    localStorage.setItem(THEME_KEY, value);
  } catch {
    // The preference still works for the current page when storage is blocked.
  }
}

function avatarKey(email) {
  return `equip-campus-avatar:${email.toLowerCase()}`;
}

export function readAvatar(email) {
  if (!email) return "";
  try {
    return localStorage.getItem(avatarKey(email)) || "";
  } catch {
    return "";
  }
}

export function saveAvatar(email, dataUrl) {
  if (!email) return;
  if (dataUrl) localStorage.setItem(avatarKey(email), dataUrl);
  else localStorage.removeItem(avatarKey(email));
}

export function optimizeAvatar(file) {
  return new Promise((resolve, reject) => {
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
      reject(new Error("Choose a JPEG, PNG, or WebP image."));
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      reject(new Error("Choose an image smaller than 2 MB."));
      return;
    }
    const url = URL.createObjectURL(file);
    const image = new Image();
    const release = () => URL.revokeObjectURL(url);
    image.onload = () => {
      try {
        const scale = Math.min(1, 256 / Math.max(image.width, image.height));
        const canvas = document.createElement("canvas");
        canvas.width = Math.max(1, Math.round(image.width * scale));
        canvas.height = Math.max(1, Math.round(image.height * scale));
        const context = canvas.getContext("2d");
        if (!context) throw new Error("Image processing is unavailable.");
        context.drawImage(image, 0, 0, canvas.width, canvas.height);
        resolve(canvas.toDataURL("image/webp", 0.82));
      } catch {
        reject(new Error("Could not process this image. Try another file."));
      } finally {
        release();
      }
    };
    image.onerror = () => {
      release();
      reject(new Error("Could not open this image. Try another file."));
    };
    image.src = url;
  });
}
