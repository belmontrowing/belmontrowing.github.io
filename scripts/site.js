// Belmont Rowing Center: the site's ONE small script (see CLAUDE.md, "The one script").
// It does exactly two things; everything still works without it.
(function () {
  // 1. Jump-link bar: mark the link of the section in view with aria-current="true"
  //    (styled like hover in theme.scss), and keep it in view in the sideways bar on phones.
  var bar = document.querySelector("#main-content > .pill-nav");
  var links = bar ? [].slice.call(bar.querySelectorAll('a[href^="#"]')) : [];
  var targets = links.map(function (a) { return document.getElementById(a.getAttribute("href").slice(1)); });
  if (links.length && targets.every(Boolean)) {
    var row = bar.querySelector("p") || bar;
    // The current section is the last one whose top has passed a "reading line" a little
    // above the middle of the window. (A jump link lands its section well above that line,
    // so the link just clicked is always the one marked.) At the very bottom of the page the
    // last section counts, even if it is too short to reach the line.
    var last = null;
    var update = function () {
      var line = window.innerHeight * 0.45, i = -1;
      targets.forEach(function (t, k) { if (t.getBoundingClientRect().top <= line) i = k; });
      var doc = document.documentElement;
      if (window.innerHeight + window.scrollY >= doc.scrollHeight - 2) i = targets.length - 1;
      links.forEach(function (a, k) {
        if (k === i) a.setAttribute("aria-current", "true"); else a.removeAttribute("aria-current");
      });
      var cur = links[i];                                     // sideways only, never vertical
      if (cur && cur !== last && row.scrollWidth > row.clientWidth) {
        row.scrollTo({ left: Math.max(0, cur.offsetLeft - row.offsetLeft - 24), behavior: "smooth" });
      }
      last = cur;
    };
    // Re-check on scroll (at most once per frame), on resize, and once the page has loaded.
    var queued = false;
    var onScroll = function () {
      if (queued) return;
      queued = true;
      requestAnimationFrame(function () { queued = false; update(); });
    };
    addEventListener("scroll", onScroll, { passive: true });
    addEventListener("resize", onScroll);
    addEventListener("load", update);
    update();
  }

  // 2. Header dropdowns (Programs, Social): Space opens them, like Enter does.
  document.addEventListener("keydown", function (e) {
    if ((e.key === " " || e.key === "Spacebar") && e.target.matches && e.target.matches(".navbar .dropdown-toggle")) {
      e.preventDefault();
      e.target.click();
    }
  });
})();
