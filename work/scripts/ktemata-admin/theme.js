(() => {
  try {
    const saved = localStorage.getItem("ktemata-theme");
    if (saved === "light" || saved === "dark") {
      document.documentElement.dataset.theme = saved;
    }
  } catch {
    // localStorage can be disabled; keep the dark default.
  }
})();
