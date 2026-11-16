/*
 * Frontstage – Startseite: Stationen blenden ein, wenn sie in den Blick kommen.
 * Ohne Skript (oder bei reduzierter Bewegung) ist alles sofort sichtbar: Die Ausgangsstellung
 * "unsichtbar" gilt nur unter .js-motion, das erst dieses Skript setzt.
 */
(function () {
  "use strict";
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduce || !("IntersectionObserver" in window)) {
    return;
  }
  var stations = document.querySelectorAll("main .station");
  var observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.2 }
  );
  document.documentElement.classList.add("js-motion");
  stations.forEach(function (station) {
    observer.observe(station);
  });
})();
