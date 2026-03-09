#!/usr/bin/env python3
"""
Add a metadata JSON field to every CSV file in the simulation campaign datasets.
The metadata conforms to the ePICRucioMetadataTags schema.

Metadata is inferred per-row from column 0 (the dataset path), falling back
to the CSV filename/path only where the row content is insufficient.
Fields that cannot be reliably inferred are set to placeholder strings.
"""

import json
import re
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent  # simulation_campaign_datasets/

# Placeholders for fields that cannot be reliably inferred
PH_SOFTWARE_RELEASE       = "%software_release%"
PH_BACKGROUND_CONFIG      = "%background_configuration%"
PH_GENERATOR              = "%generator%"
PH_PHYSICS_PROCESS        = "%physics_process%"
PH_HADRON_SPECIES         = "%hadron_species%"


# ---------------------------------------------------------------------------
# Inference functions — parse from row_path (col 0) first, use file_rel_path
# only as supplementary context.
# ---------------------------------------------------------------------------

def infer_physics_process(row_path: str, file_rel_path: str) -> list | str:
    src = (row_path + " " + file_rel_path).upper()
    if any(x in src for x in [
        "BACKGROUNDS/", "BEAMGAS", "SYNRAD", "TOUSCHEK", "BREMS",
        "COULOMB", "MERGED", "BGMERGED", "BGPLUSSYNRAD", "SR/", "SINGLE/",
    ]):
        return ["other"]
    if "SIDIS/" in src:
        return ["semi_inclusive"]
    if "DDIS/" in src:
        return ["inclusive"]
    if "DIS/" in src:
        return ["inclusive"]
    if any(x in src for x in [
        "EXCLUSIVE/", "DVCS", "DVMP", "DEMP", "DDVCS", "DIFFRACTIVE",
        "MESON_SF", "OMEGA", "RHO", "UPSILON", "TCS", "SPECTROSCOPY",
        "UCHANNEL", "PHOTOPRODUCTION",
    ]):
        return ["exclusive_diff_tag"]
    return PH_PHYSICS_PROCESS


SPECIES_PATTERNS = [
    (r'eAu\b',  "Au"),
    (r'eCu\b',  "Cu"),
    (r'eHe3\b', "He3"),
    (r'eH2\b',  "H2"),
    (r'eRu\b',  "Ru"),
    (r'eCa\b',  "Ca"),
    (r'ePb\b',  "Pb"),
    (r'\bep\b', "p"),
    (r'\ben\b', "n"),
]

def infer_hadron_species(row_path: str, file_rel_path: str) -> str:
    src = row_path + " " + file_rel_path
    for pattern, species in SPECIES_PATTERNS:
        if re.search(pattern, src):
            return species
    if re.search(r'[Pp]roton[Bb]eam[Gg]as', src):
        return "p"
    # Electron-only beam-gas (no hadron beam)
    if re.search(r'[Ee]lectron[Bb]eam[Gg]as', src):
        return PH_HADRON_SPECIES
    return PH_HADRON_SPECIES


def infer_beam_energies(row_path: str, file_rel_path: str) -> tuple:
    """Return (e_energy, h_energy); None when not parseable."""
    src = row_path + " " + file_rel_path
    # Standard ExH pattern: 10x100, 18x275, 5x41, 10x115, 10x130, 10x166, etc.
    m = re.search(r'(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)', src)
    if m:
        return float(m.group(1)), float(m.group(2))
    # Proton beam-gas: ProtonBeamGas_275GeV — must check before generic _XGeV_
    m = re.search(r'[Pp]roton[Bb]eam[Gg]as[_/](\d+)GeV', src)
    if m:
        return None, float(m.group(1))
    # Electron beam-gas with single energy: _18GeV_, GETaLM..._10GeV_
    m = re.search(r'[Ee]lectron\w*[_/](\d+)GeV', src)
    if m:
        return float(m.group(1)), None
    m = re.search(r'_(\d+)GeV[_/]', src)
    if m:
        return float(m.group(1)), None
    return None, None


def infer_q2_range(row_path: str) -> dict | None:
    """Parse Q2 range from the row dataset path. Returns None if not present."""
    # q2_XtoY  e.g. q2_1to10, q2_10to100
    m = re.search(r'q2[_=](\d+(?:\.\d+)?)to(\d+(?:\.\d+)?)', row_path, re.IGNORECASE)
    if m:
        return {"min": float(m.group(1)), "max": float(m.group(2))}
    # q2_X_Y  e.g. q2_3_10, q2_10_20, q2_0_10
    m = re.search(r'q2[_=](\d+(?:\.\d+)?)_(\d+(?:\.\d+)?)', row_path, re.IGNORECASE)
    if m:
        return {"min": float(m.group(1)), "max": float(m.group(2))}
    # Q2ofXtoY  e.g. Q2of0to1, Q2of1to5
    m = re.search(r'Q2of(\d+(?:\.\d+)?)to(\d+(?:\.\d+)?)', row_path)
    if m:
        return {"min": float(m.group(1)), "max": float(m.group(2))}
    # minQ2=X  (lower bound only)
    m = re.search(r'minQ2[=_](\d+(?:\.\d+)?)', row_path, re.IGNORECASE)
    if m:
        return {"min": float(m.group(1)), "max": None}
    # Single Q2 value: /q2_15/
    m = re.search(r'[/_]q2_(\d+(?:\.\d+)?)(?=[/_]|$)', row_path, re.IGNORECASE)
    if m:
        v = float(m.group(1))
        return {"min": v, "max": v}
    return None


GENERATOR_PATTERNS = [
    (r'[Pp]ythia8',       "Pythia8"),
    (r'[Pp]ythia6',       "Pythia6"),
    (r'BeAGLE',           "BeAGLE"),
    (r'DJANGOH',          "DJANGOH"),
    (r'[Rr]apgap',        "RAPGAP"),
    (r'[Ss]artre',        "Sartre"),
    (r'eSTARlight',       "eSTARlight"),
    (r'lAger',            "lAger"),
    (r'\bslight\b',       "eSTARlight"),
    (r'DEMPgen',          "DEMPgen"),
    (r'EpIC',             "EpIC"),
    (r'eicMesonSFGen',    "eicMesonSFGen"),
    (r'HEPMC_merger',     "HEPMC_merger"),
    (r'GETaLM',           "GETaLM"),
    (r'dataprod_rel',     "EIC_ESR_Xsuite"),
    (r'bgmerged',         "HEPMC_merger"),
    (r'bgplussynrad',     "HEPMC_merger"),
]

def infer_generator(row_path: str, file_rel_path: str) -> str:
    src = row_path + " " + file_rel_path
    for pattern, name in GENERATOR_PATTERNS:
        if re.search(pattern, src):
            return name
    return PH_GENERATOR


def build_metadata(row_path: str, file_rel_path: str) -> dict:
    e_energy, h_energy = infer_beam_energies(row_path, file_rel_path)
    q2 = infer_q2_range(row_path)

    meta = {
        "software_release":        PH_SOFTWARE_RELEASE,
        "physics_process":         infer_physics_process(row_path, file_rel_path),
        "electron_beam_energy":    e_energy,
        "hadron_beam_energy":      h_energy,
        "background_configuration": PH_BACKGROUND_CONFIG,
        "hadron_species":          infer_hadron_species(row_path, file_rel_path),
        "generator":               infer_generator(row_path, file_rel_path),
    }
    if q2 is not None:
        meta["q2_range"] = q2
    return meta


# ---------------------------------------------------------------------------
# CSV processing
# ---------------------------------------------------------------------------

def process_csv(csv_path: Path) -> None:
    file_rel_path = str(csv_path.relative_to(BASE))
    lines = csv_path.read_text().splitlines()
    if not lines:
        return

    new_lines = []
    for line in lines:
        line = line.rstrip("\n")
        if not line.strip():
            new_lines.append(line)
            continue

        # Index lines: entries that are just paths to other .csv files — leave unchanged
        if re.match(r'^[^\s,]+\.csv\s*$', line.strip()):
            new_lines.append(line)
            continue

        # Column 0 is the dataset path (everything before the first comma)
        row_path = line.split(",")[0].strip()

        meta = build_metadata(row_path, file_rel_path)
        json_str = json.dumps(meta, separators=(",", ":"))
        # Wrap in double quotes and escape internal quotes for valid CSV encoding
        quoted = '"' + json_str.replace('"', '""') + '"'
        new_lines.append(line + "," + quoted)

    csv_path.write_text("\n".join(new_lines) + "\n")


def main():
    csv_files = sorted(BASE.rglob("*.csv"))
    print(f"Processing {len(csv_files)} CSV files...", file=sys.stderr)
    for i, f in enumerate(csv_files, 1):
        process_csv(f)
        print(f"  [{i}/{len(csv_files)}] {f.relative_to(BASE)}", file=sys.stderr)
    print("Done.", file=sys.stderr)


if __name__ == "__main__":
    main()
