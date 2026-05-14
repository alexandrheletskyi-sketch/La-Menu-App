import json
import shutil
from pathlib import Path

path = Path("Localizable.xcstrings")
backup = Path("Localizable_backup_before_pl_fix.xcstrings")

shutil.copy(path, backup)

with path.open("r", encoding="utf-8") as f:
    data = json.load(f)

strings = data.get("strings", {})

manual_translations = {
    "": {"en": "", "pl": ""},
    "#FF0043": {"en": "#FF0043", "pl": "#FF0043"},
    "%.0f zł": {"en": "%.0f zł", "pl": "%.0f zł"},
    "%@ / miesiąc": {"en": "%@ / month", "pl": "%@ / miesiąc"},
    "%1$lld / %2$lld zamówień": {"en": "%1$lld / %2$lld orders", "pl": "%1$lld / %2$lld zamówień"},
    "%lld": {"en": "%lld", "pl": "%lld"},
    "%lld SMS": {"en": "%lld SMS", "pl": "%lld SMS"},
    "%lld zł": {"en": "%lld zł", "pl": "%lld zł"},
    "•": {"en": "•", "pl": "•"},

    "Język i waluta": {"en": "Language and currency", "pl": "Język i waluta"},
    "Język strony": {"en": "Page language", "pl": "Język strony"},
    "Język strony menu": {"en": "Menu page language", "pl": "Język strony menu"},
    "Waluta": {"en": "Currency", "pl": "Waluta"},
    "Waluta strony": {"en": "Page currency", "pl": "Waluta strony"},
    "Wybierz język, w którym będzie wyświetlana publiczna strona menu": {
        "en": "Choose the language in which the public menu page will be displayed",
        "pl": "Wybierz język, w którym będzie wyświetlana publiczna strona menu"
    },
    "Ta waluta będzie pokazywana przy cenach produktów i kosztach dostawy": {
        "en": "This currency will be shown for product prices and delivery costs",
        "pl": "Ta waluta będzie pokazywana przy cenach produktów i kosztach dostawy"
    },
    "Te ustawienia będą używane na publicznej stronie menu": {
        "en": "These settings will be used on the public menu page",
        "pl": "Te ustawienia będą używane na publicznej stronie menu"
    },
    "Po zapisaniu ustawienia będą używane na publicznej stronie menu": {
        "en": "After saving, these settings will be used on the public menu page",
        "pl": "Po zapisaniu ustawienia będą używane na publicznej stronie menu"
    },
    "Tutaj możesz zmienić język, walutę i główny kolor swojej strony menu": {
        "en": "Here you can change the language, currency and main color of your menu page",
        "pl": "Tutaj możesz zmienić język, walutę i główny kolor swojej strony menu"
    },
    "Your menus": {"en": "Your menus", "pl": "Twoje menu"},
    "Loading...": {"en": "Loading...", "pl": "Ładowanie..."},
    "Home": {"en": "Home", "pl": "Start"},
    "Manage your restaurant menus and public links": {
        "en": "Manage your restaurant menus and public links",
        "pl": "Zarządzaj menu restauracji i linkami publicznymi"
    },
    "Privacy Policy": {"en": "Privacy Policy", "pl": "Polityka prywatności"},
    "Terms of Use": {"en": "Terms of Use", "pl": "Warunki korzystania"},
    "Business": {"en": "Business", "pl": "Business"},
    "Free": {"en": "Free", "pl": "Free"},
    "Plus": {"en": "Plus", "pl": "Plus"},
    "Premium": {"en": "Premium", "pl": "Premium"},
    "La Menu": {"en": "La Menu", "pl": "La Menu"},
    "La Menu Business": {"en": "La Menu Business", "pl": "La Menu Business"},
    "MENU": {"en": "MENU", "pl": "MENU"},
    "Menu": {"en": "Menu", "pl": "Menu"},
    "OK": {"en": "OK", "pl": "OK"},
    "min": {"en": "min", "pl": "min"},
    "lamenu.pl/%@": {"en": "lamenu.pl/%@", "pl": "lamenu.pl/%@"}
}

def make_unit(value: str):
    return {
        "stringUnit": {
            "state": "translated",
            "value": value
        }
    }

def is_technical_key(key: str) -> bool:
    return (
        key.startswith("onboarding.")
        or key.startswith("common.")
        or key.startswith("%")
        or key.startswith("#")
        or key == ""
        or key == "•"
    )

def looks_polish_text(key: str) -> bool:
    polish_chars = "ąćęłńóśźżĄĆĘŁŃÓŚŹŻ"
    polish_words = [
        "nie", "jest", "został", "została", "zostały", "zapisz", "usuń",
        "wybierz", "dodaj", "zamówień", "zamówienia", "profil", "lokalu",
        "stronie", "publiczny", "dostępne", "przyjmowanie", "płatności",
        "zdjęcie", "hasło", "konto", "pozycja", "kategoria", "alergen"
    ]

    lower = key.lower()

    return (
        any(ch in key for ch in polish_chars)
        or any(word in lower for word in polish_words)
    )

fixed_pl = 0
fixed_empty = 0
fixed_placeholder = 0

for key, item in strings.items():
    if not isinstance(item, dict):
        continue

    item.setdefault("localizations", {})
    loc = item["localizations"]

    if key in manual_translations:
        loc["en"] = make_unit(manual_translations[key]["en"])
        loc["pl"] = make_unit(manual_translations[key]["pl"])
        fixed_empty += 1
        continue

    if "pl" not in loc and not is_technical_key(key) and looks_polish_text(key):
        loc["pl"] = make_unit(key)
        fixed_pl += 1

    if "pl" not in loc and key in ["Plan", "Limit", "Logo", "SMS", "BLIK"]:
        loc["pl"] = make_unit(key)
        fixed_pl += 1

placeholder_fixes = {
    "Aktualny plan: %@": {
        "en": "Current plan: %@",
        "pl": "Aktualny plan: %@"
    },
    "Aktywny plan: %@": {
        "en": "Active plan: %@",
        "pl": "Aktywny plan: %@"
    }
}

for key, values in placeholder_fixes.items():
    if key in strings:
        strings[key].setdefault("localizations", {})
        strings[key]["localizations"]["en"] = make_unit(values["en"])
        strings[key]["localizations"]["pl"] = make_unit(values["pl"])
        fixed_placeholder += 1

with path.open("w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Done")
print(f"Backup saved as: {backup}")
print(f"Added Polish translations: {fixed_pl}")
print(f"Filled manual/empty translations: {fixed_empty}")
print(f"Fixed placeholders: {fixed_placeholder}")