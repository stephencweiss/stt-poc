/// Display-only allowlists. These do not change the speech recognition prompt.
enum FormattingVocabulary {
    static let headings = [
        "procedure": "Procedure", "indication": "Indication", "access": "Access",
        "findings": "Findings", "intervention": "Intervention", "hemodynamics": "Hemodynamics",
        "complications": "Complications", "plan": "Plan",
    ]
    static let spelling = [
        "pci": "PCI", "tavr": "TAVR", "lad": "LAD", "rca": "RCA", "ivus": "IVUS",
        "ffr": "FFR", "sapien": "SAPIEN", "evolut": "Evolut",
    ]
}
