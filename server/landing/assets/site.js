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
    // Schon ein sichtbarer Rand genügt: Ein Schwellwert als Anteil wird bei Stationen, die höher als
    // mehrere Bildschirme sind (390 px, große Schrift), nie erreicht – sie blieben sonst unsichtbar.
    // Der negative Rand unten verzögert das Einblenden, bis die Station ein Stück im Bild ist.
    { threshold: 0, rootMargin: "0px 0px -15% 0px" }
  );
  document.documentElement.classList.add("js-motion");
  stations.forEach(function (station) {
    observer.observe(station);
  });
})();
