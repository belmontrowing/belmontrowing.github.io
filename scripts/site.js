// Belmont Rowing Center: the site's ONE small script (see CLAUDE.md, "The one script").
// It does exactly two things; everything still works without it.
(function () {
  // 1. Jump-link bar: mark the link of the section in view with aria-current="true"
  //    (styled like hover in theme.scss), and keep it in view in the sideways bar on phones.
  var bar = document.querySelector("#main-content > .pill-nav");
  var links = bar ? [].slice.call(bar.querySelectorAll('a[href^="#"]')) : [];
  var targets = links.map(function (a) { return document.getElementById(a.getAttribute("href").slice(1)); });
  if (links.length && targets.every(Boolean) && "IntersectionObserver" in window) {
    var row = bar.querySelector("p") || bar;
    // The "reading line": just below the header (and the bar, where it sticks).
    var lineY = function () {
      var h = document.getElementById("quarto-header");
      var sticky = getComputedStyle(bar).position === "sticky";
      return (h ? h.offsetHeight : 0) + (sticky ? bar.offsetHeight : 0) + 25;   // = scroll-padding-top + 1
    };
    var last = null;
    var update = function () {
      var line = lineY(), i = -1;
      targets.forEach(function (t, k) { if (t.getBoundingClientRect().top <= line) i = k; });
      links.forEach(function (a, k) {
        if (k === i) a.setAttribute("aria-current", "true"); else a.removeAttribute("aria-current");
      });
      var cur = links[i];                                     // sideways only, never vertical
      if (cur && cur !== last && row.scrollWidth > row.clientWidth) {
        row.scrollTo({ left: Math.max(0, cur.offsetLeft - row.offsetLeft - 24), behavior: "smooth" });
      }
      last = cur;
    };
    // Watch a 1px strip at the reading line: a callback fires whenever a section crosses it.
    var io;
    var watch = function () {
      if (io) io.disconnect();
      var line = lineY();
      io = new IntersectionObserver(update, { rootMargin: -line + "px 0px " + -(innerHeight - line - 1) + "px 0px" });
      targets.forEach(function (t) { io.observe(t); });
      update();
    };
    addEventListener("resize", watch);
    watch();
  }

  // 2. Header dropdowns (Programs, Social): Space opens them, like Enter does.
  document.addEventListener("keydown", function (e) {
    if ((e.key === " " || e.key === "Spacebar") && e.target.matches && e.target.matches(".navbar .dropdown-toggle")) {
      e.preventDefault();
      e.target.click();
    }
  });
})();
