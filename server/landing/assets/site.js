/*
 * Frontstage – Startseite: Bewegung und die kleinen Bedienstellen.
 * Ohne dieses Skript ist alles sichtbar und im Endzustand: Ausgangsstellungen gelten nur unter html.js.
 * Die Seite speichert nichts und sendet nichts.
 */
(function () {
  "use strict";
  var doc = document;
  var root = doc.documentElement;
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var hasIO = "IntersectionObserver" in window;

  function each(selector, fn, scope) {
    Array.prototype.forEach.call((scope || doc).querySelectorAll(selector), fn);
  }

  root.classList.add("js");

  function init() {
    header();
    reveals();
    stage();
    timer();
    faq();
  }

  /* Kopf: wird schmaler, die Kapsel „Jetzt“ zeigt die Uhrzeit der Station im Blick */
  function header() {
    var head = doc.querySelector(".site-header");
    var day = doc.getElementById("tag");
    var clock = doc.querySelector("[data-clock]");
    var ticking = false;

    function update() {
      ticking = false;
      head.classList.toggle("is-scrolled", window.scrollY > 24);
      if (!day) {
        return;
      }
      var rect = day.getBoundingClientRect();
      var mid = window.innerHeight * 0.5;
      var progress = (mid - rect.top) / rect.height;
      root.classList.toggle("in-day", progress > 0 && progress < 1);
      root.style.setProperty("--day", Math.max(0, Math.min(1, progress)).toFixed(4));
    }

    window.addEventListener(
      "scroll",
      function () {
        if (!ticking) {
          ticking = true;
          window.requestAnimationFrame(update);
        }
      },
      { passive: true }
    );
    window.addEventListener("resize", update);
    update();

    if (!hasIO || !clock) {
      return;
    }
    // Eine schmale Zone in Bildmitte: Die Station, die sie berührt, stellt die Uhr.
    var watcher = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          var time = entry.target.getAttribute("data-time");
          if (!entry.isIntersecting || clock.textContent === time) {
            return;
          }
          clock.textContent = time;
          clock.classList.remove("tick");
          void clock.offsetWidth; // Neustart der Animation
          clock.classList.add("tick");
        });
      },
      { rootMargin: "-50% 0px -50% 0px", threshold: 0 }
    );
    each("[data-time]", function (station) {
      watcher.observe(station);
    });
  }

  /* Stationen: bekommen .is-in, sobald sie ein Stück im Bild sind */
  function reveals() {
    var targets = doc.querySelectorAll("[data-reveal]");
    if (reduce || !hasIO) {
      each("[data-reveal]", function (el) {
        el.classList.add("is-in");
      });
      return;
    }
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-in");
            observer.unobserve(entry.target);
          }
        });
      },
      // Schon ein sichtbarer Rand genügt (hohe Stationen erreichen keinen Anteil-Schwellwert);
      // der negative Rand unten wartet, bis die Station ein Stück im Bild ist.
      { threshold: 0, rootMargin: "0px 0px -18% 0px" }
    );
    Array.prototype.forEach.call(targets, function (el) {
      observer.observe(el);
    });
  }

  /* 8:40 – Tipp auf eine Kachel: Die Kapsel wandert, das Smartboard wechselt */
  function stage() {
    var scene = doc.querySelector("[data-stage]");
    if (!scene) {
      return;
    }
    var capsule = scene.querySelector("[data-capsule]");
    var status = scene.querySelector("[data-status]");
    var buttons = scene.querySelectorAll(".tile-btn");
    var touched = false;

    function show(button, announce) {
      var same = button.getAttribute("aria-pressed") === "true" && !capsule.classList.contains("is-off");
      Array.prototype.forEach.call(buttons, function (other) {
        other.setAttribute("aria-pressed", other === button ? "true" : "false");
      });
      scene.setAttribute("data-show", button.getAttribute("data-show"));
      button.classList.remove("tapped");
      void button.offsetWidth;
      button.classList.add("tapped");
      if (!same) {
        button.parentNode.appendChild(capsule);
        capsule.classList.remove("is-off", "pop");
        void capsule.offsetWidth;
        capsule.classList.add("pop");
      }
      if (announce && status) {
        status.textContent = "Am Smartboard: " + button.getAttribute("data-label");
      }
    }

    Array.prototype.forEach.call(buttons, function (button) {
      button.addEventListener("click", function () {
        touched = true;
        show(button, true);
      });
    });

    // Der Ablauf beim ersten Blick: erst der Klassenbildschirm, dann tippt die Seite selbst.
    if (reduce || !hasIO) {
      return;
    }
    scene.setAttribute("data-show", "class");
    capsule.classList.add("is-off");
    var once = new IntersectionObserver(
      function (entries) {
        if (!entries[0].isIntersecting) {
          return;
        }
        once.disconnect();
        window.setTimeout(function () {
          if (!touched) {
            show(buttons[0], false);
          }
        }, 1700);
      },
      { threshold: 0.45 }
    );
    once.observe(scene);
  }

  /* 9:16 – der Timer am Klassenbildschirm läuft, solange er im Bild ist */
  function timer() {
    var el = doc.querySelector("[data-timer]");
    if (!el || reduce || !hasIO) {
      return;
    }
    var start = 120;
    var left = start;
    var id = 0;

    function paint() {
      var seconds = left % 60;
      el.textContent = Math.floor(left / 60) + ":" + (seconds < 10 ? "0" : "") + seconds;
    }

    new IntersectionObserver(function (entries) {
      window.clearInterval(id);
      if (entries[0].isIntersecting) {
        id = window.setInterval(function () {
          left = left > 0 ? left - 1 : start;
          paint();
        }, 1000);
      }
    }).observe(el);
  }

  /* Fragen: details/summary gehen weich auf und zu (ohne Skript: sofort) */
  function faq() {
    if (reduce || !Element.prototype.animate) {
      return;
    }
    each(".faq details", function (details) {
      var summary = details.querySelector("summary");
      var running = null;

      summary.addEventListener("click", function (event) {
        event.preventDefault();
        var from = details.offsetHeight;
        var opening = !details.open || (running && details.classList.contains("is-closing"));
        if (running) {
          running.cancel();
        }
        details.classList.toggle("is-closing", !opening);
        if (opening) {
          details.open = true;
        }
        var to = opening ? details.scrollHeight : summary.offsetHeight;
        running = details.animate(
          { height: [from + "px", to + "px"] },
          { duration: 420, easing: "cubic-bezier(0.16, 1, 0.3, 1)" }
        );
        running.onfinish = function () {
          running = null;
          if (!opening) {
            details.open = false;
          }
          details.classList.remove("is-closing");
        };
      });
    });
  }

  if (doc.readyState === "loading") {
    doc.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
