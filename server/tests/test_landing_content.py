"""Inhaltsprüfung der Startseite ohne Browser: keine Fremdserver, Inline-Skripte oder Personennamen."""

import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

LANDING = Path(__file__).parents[1] / "landing"
PAGES = [LANDING / "index.html", LANDING / "impressum" / "index.html", LANDING / "datenschutz" / "index.html"]
ALLOWED_CLASSES = {"7a", "8a", "8b", "9c", "6c"}
# Einziger erlaubter externer Verweis neben mailto: der App-Store-Platzhalter (Entscheidung 4 des Teilplans).
ALLOWED_EXTERNAL_HOSTS = {"apps.apple.com"}
TEXT_ATTRS = {"aria-label", "alt", "title"}
URL_ATTRS = {"href", "src", "srcset", "poster", "data", "action"}

# Gängige deutsche Vornamen (Sperrliste); ganze Wörter, mit Großbuchstaben am Anfang.
FIRST_NAMES = """
Alexander Andreas Anna Annika Anja Anke Antje Barbara Ben Benjamin Bernd Birgit Brigitte Carina Carsten
Christian Christina Christine Christoph Claudia Daniel Daniela David Dennis Dieter Dirk Dominik Eva Elena
Elisabeth Emil Emma Erik Fabian Felix Florian Frank Franziska Friedrich Gabriele Georg Gerhard Hannah
Heike Heinz Helga Helmut Henrik Hermann Holger Ines Ingrid Jan Jana Jannik Jens Jessica Joachim Johanna
Johannes Jonas Jörg Julia Julian Jürgen Karin Karl Katharina Kerstin Klaus Kristina Lars Laura Lea Lena
Leon Leonie Lisa Lukas Luca Luisa Maik Manuel Marcel Marco Marcus Maria Marie Marion Marius Markus Martin
Martina Matthias Max Maximilian Melanie Michael Michaela Mia Mike Monika Nadine Nico Nicole Nils Nina
Norbert Olaf Oliver Oskar Pascal Patrick Paul Paula Peter Petra Philipp Rainer Ralf Regina Renate Robert
Roland Sabine Sandra Sarah Sascha Sebastian Silke Simon Simone Sophie Stefan Stefanie Stephan Susanne
Sven Tanja Thomas Tim Timo Tobias Tom Ulrich Ulla Ursula Uwe Vanessa Verena Viktoria Walter Werner
Wolfgang Yvonne Lukas Noah Elias Finn Henry Theo Anton Ole Jakob Mats Merle Lilly Clara Charlotte Ida
Greta Frieda Mathilde Jule Svenja Kevin Marvin Dustin Justin Jacqueline Mandy Steffen Torsten Thorsten
Detlef Gisela Hildegard Ilse Irmgard Jutta Rolf Rüdiger Siegfried Manfred Günter Gunter Harald Horst
Kurt Lothar Hubert Ernst Fritz Heinrich Wilhelm Otto Emilia Lotta Leni Mila Ella Luise
""".split()
NAME_RE = re.compile(r"\b(?:" + "|".join(sorted(set(FIRST_NAMES))) + r")\b")
TITLE_RE = re.compile(r"\b(?:Frau|Herr) [A-ZÄÖÜ]")
CLASS_RE = re.compile(r"\b\d{1,2}[a-z]\b")


class Collector(HTMLParser):
    """Sammelt Elemente, Attribute und sichtbaren Text einer Seite."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.tags: list[tuple[str, dict[str, str | None]]] = []
        self.text: list[str] = []
        self._skip = 0
        self.script_inline = 0
        self._script_has_src = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        a = dict(attrs)
        self.tags.append((tag, a))
        if tag in ("script", "style"):
            self._skip += 1
            if tag == "script":
                self._script_has_src = "src" in a
        for name, value in attrs:
            if name in TEXT_ATTRS and value:
                self.text.append(value)

    def handle_endtag(self, tag: str) -> None:
        if tag in ("script", "style") and self._skip:
            self._skip -= 1

    def handle_data(self, data: str) -> None:
        if self._skip:
            if data.strip() and not self._script_has_src:
                self.script_inline += 1
            return
        self.text.append(data)


def parse(path: Path) -> Collector:
    collector = Collector()
    collector.feed(path.read_text(encoding="utf-8"))
    return collector


def all_files() -> list[Path]:
    return [p for p in LANDING.rglob("*") if p.is_file()]


def test_required_pages_exist():
    for page in PAGES:
        assert page.is_file(), f"{page} fehlt"


def _is_external(value: str) -> bool:
    return value.strip().lower().startswith(("http://", "https://", "//"))


def test_no_external_resources():
    for page in PAGES:
        for tag, attrs in parse(page).tags:
            for name, value in attrs.items():
                if name not in URL_ATTRS or not value:
                    continue
                for part in re.split(r"\s*,\s*", value) if name == "srcset" else [value]:
                    url = part.split()[0] if part.split() else ""
                    if not _is_external(url):
                        continue
                    is_link = tag == "a" and name == "href"
                    host = urlparse(url).hostname
                    assert is_link and host in ALLOWED_EXTERNAL_HOSTS, f"{page.name}: externe Ressource {url}"
    for css in LANDING.rglob("*.css"):
        source = css.read_text(encoding="utf-8")
        assert not re.search(r"@import", source), f"{css}: @import"
        for match in re.finditer(r"url\(\s*['\"]?([^)'\"]+)", source):
            assert not _is_external(match.group(1)), f"{css}: externe URL {match.group(1)}"


def test_no_inline_styles_or_scripts():
    for page in PAGES:
        collector = parse(page)
        assert collector.script_inline == 0, f"{page.name}: Inline-Skript"
        for tag, attrs in collector.tags:
            assert tag != "style", f"{page.name}: <style>-Block"
            assert "style" not in attrs, f"{page.name}: style-Attribut an <{tag}>"
            bad = [n for n in attrs if n.startswith("on")]
            assert not bad, f"{page.name}: Ereignisattribut {bad} an <{tag}>"


def _visible_text(page: Path) -> str:
    return " ".join(parse(page).text)


def test_no_person_names():
    for page in PAGES:
        text = _visible_text(page)
        found = NAME_RE.findall(text) + TITLE_RE.findall(text)
        assert not found, f"{page.name}: Personenname {found}"


def test_only_allowed_classes():
    for page in PAGES:
        found = set(CLASS_RE.findall(_visible_text(page)))
        assert found <= ALLOWED_CLASSES, f"{page.name}: unerlaubte Klassen {found - ALLOWED_CLASSES}"


def test_lang_and_landmarks():
    for page in PAGES:
        assert parse(page).tags[0][0] == "html"
        assert dict(parse(page).tags[0][1]).get("lang") == "de", f"{page.name}: lang"
    tags = parse(LANDING / "index.html").tags
    names = [t for t, _ in tags]
    assert names.count("main") == 1
    assert names.count("header") >= 1
    assert names.count("footer") >= 1
    assert any(t == "a" and a.get("href") == "#inhalt" for t, a in tags), "Sprunglink fehlt"
    assert any(t == "main" and a.get("id") == "inhalt" for t, a in tags), "Sprungziel #inhalt fehlt"


def test_size_budget():
    files = all_files()
    assert all(p.stat().st_size <= 120 * 1024 for p in files), "Datei über 120 KB"
    without_fonts = sum(p.stat().st_size for p in files if "fonts" not in p.parts)
    total = sum(p.stat().st_size for p in files)
    assert without_fonts <= 200 * 1024, f"ohne Schriften {without_fonts} Byte"
    assert total <= 400 * 1024, f"gesamt {total} Byte"


def test_fonts_have_license():
    fonts = list((LANDING / "assets" / "fonts").glob("*.woff2"))
    assert fonts, "keine Schriften ausgeliefert"
    assert (LANDING / "assets" / "fonts" / "OFL.txt").is_file()


def test_index_has_meta_and_icon():
    tags = parse(LANDING / "index.html").tags
    metas = {a.get("name"): a.get("content") for t, a in tags if t == "meta"}
    assert metas.get("description")
    assert sum(1 for t, a in tags if t == "meta" and a.get("name") == "theme-color") == 2
    assert any(t == "link" and a.get("rel") == "icon" for t, a in tags)
    assert "Frontstage – Dein Unterricht, vorbereitet" in (LANDING / "index.html").read_text(encoding="utf-8")


def test_required_sections():
    page = LANDING / "index.html"
    ids = {a.get("id") for _, a in parse(page).tags if a.get("id")}
    required = {
        "tag",
        "morgen",
        "smartboard",
        "tafel",
        "vorbereiten",
        "vorplanen",
        "farben",
        "preise",
        "daten",
        "fragen",
        "testen",
    }
    assert required <= ids, f"Abschnitte fehlen: {required - ids}"
    text = _visible_text(page)
    assert "kein Abo" in text
    assert not re.search(r"\d+,\d{2}\s?€", text), "Eurobetrag auf der Startseite"


def test_privacy_page_states_facts():
    # AK-65: die Sachaussagen der Datenschutzerklärung stehen auf der Seite
    text = _visible_text(LANDING / "datenschutz" / "index.html")
    for phrase in ("zwölf Monate", "Kennung", "keine Cookies", "Bildschirmfotos", "Geräteangaben"):
        assert phrase in text, f"Datenschutz: '{phrase}' fehlt"


def test_legal_pages_are_marked_as_draft():
    for name in ("impressum", "datenschutz"):
        text = _visible_text(LANDING / name / "index.html")
        assert "[Platzhalter" in text, f"{name}: Platzhalter fehlt"
        assert "Entwurf – vor Veröffentlichung von einem Menschen prüfen und ersetzen (Q-44)" in text, (
            f"{name}: Entwurf-Hinweis fehlt"
        )


def test_footer_links_legal_pages():
    hrefs = {a.get("href") for t, a in parse(LANDING / "index.html").tags if t == "a"}
    assert {"/impressum/", "/datenschutz/"} <= hrefs


def test_legal_pages_are_not_indexed_and_keep_internal_comment():
    for name in ("impressum", "datenschutz"):
        source = (LANDING / name / "index.html").read_text(encoding="utf-8")
        assert 'name="robots" content="noindex"' in source, f"{name}: noindex fehlt"
    imprint = (LANDING / "impressum" / "index.html").read_text(encoding="utf-8")
    assert "<!-- Q-31 -->" in imprint
    assert "Markenprüfung" not in _visible_text(LANDING / "impressum" / "index.html")


def _figure_sources(page: Path) -> list[str]:
    return re.findall(r"<figure\b.*?</figure>", page.read_text(encoding="utf-8"), flags=re.S)


def test_smartboard_capsule_sits_on_shown_material():
    # UI-12: die Kapsel „Am Smartboard" steht auf der Kachel des gezeigten Materials, nicht auf der Tafel
    source = (LANDING / "index.html").read_text(encoding="utf-8")
    station = re.search(r'id="smartboard".*?</section>', source, flags=re.S).group(0)
    tiles = re.findall(r'<div class="app-tile[^"]*">(.*?)</div>', station, flags=re.S)
    with_capsule = [t for t in tiles if "Am Smartboard" in t]
    assert len(with_capsule) == 1
    assert "Unit 3 Präsentation" in with_capsule[0]


def test_substitution_signal_is_not_orange():
    # UI-11: „Vertretung" trägt Textfarbe in Symbol und Wort; Orange heißt „Material nicht verfügbar"
    css = (LANDING / "assets" / "illustrations.css").read_text(encoding="utf-8")
    base = re.search(r"\.signal::before\s*\{(.*?)\}", css, flags=re.S).group(1)
    assert "--app-unavailable" not in base
    assert "var(--app-text)" in base
    assert re.search(r"\.signal--unavailable::before\s*\{[^}]*--app-unavailable", css)


def test_no_empty_or_padded_class_attributes():
    for page in PAGES:
        source = page.read_text(encoding="utf-8")
        assert 'class=""' not in source, f"{page.name}: leeres class-Attribut"
        assert not re.search(r'class="[^"]*\s"', source), f"{page.name}: Leerzeichen am Ende von class"


def test_consistent_terms_on_index():
    text = _visible_text(LANDING / "index.html")
    assert "PRÄSENTATION" not in text, "Dateiart einheitlich als PPTX"
    assert "Jahresplanung" not in text, "Glossar: Jahresplan"
    assert "Woche 47" not in text, "Schulwochen wie im Jahresplan zählen"
    assert "laufende Stunde" not in text, "um 7:30 läuft noch keine Stunde"


def test_example_data_follows_plan_list():
    text = _visible_text(LANDING / "index.html")
    outside_list = (
        "Arbeitsblatt Past tense",
        "Brüche",
        "Balladen",
        "Wrap-up",
        "Unit 3 Practice",
        "Unit 4 Travel",
    )
    for outside in outside_list:
        assert outside not in text, f"Beispieldaten außerhalb der Planliste: {outside}"


def test_privacy_page_screenshot_and_reader_facts():
    text = _visible_text(LANDING / "datenschutz" / "index.html")
    # FR-17.4: das Bild des aktuellen Fensters ist vorbelegt, nicht eingeschaltet
    assert "Bildschirmfotos, nur wenn du sie einschaltest" not in text
    assert "aktuellen Fensters" in text
    assert "Verwaltungsseite" in text, "FR-19.1: wer die Rückmeldung liest"
