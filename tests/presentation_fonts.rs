// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: GPL-3.0-or-later
//! The presentation tokens may carry the theme's font families (ADR-078
//! step 4c, owner 2026-11-02), so a display shell renders them from the
//! batch instead of reading the app's theme. The block is optional: a
//! Core that omits it, and every fixture recorded before it, still reads.
use vauchi_contract::{PresentationFonts, PresentationTokens};

const WITHOUT_FONTS: &str = r##"{
  "spacing_small": 8, "spacing_medium": 16, "spacing_large": 24,
  "corner_radius": 12, "minimum_target_size": 48,
  "colors": {
    "background": "#1e1e2e", "surface": "#181825", "text": "#cdd6f4",
    "text_muted": "#a6adc8", "accent": "#89b4fa", "border": "#45475a",
    "success": "#a6e3a1", "warning": "#fab387", "error": "#f38ba8",
    "surface_input": "#28293a", "surface_muted": "#313244",
    "surface_elevated": "#1e1e2e"
  }
}"##;

// @scenario: generic_presentation_protocol.feature :: Invalid boundary input fails safely
#[test]
fn tokens_without_a_fonts_block_still_read_and_carry_none() {
    let tokens: PresentationTokens =
        serde_json::from_str(WITHOUT_FONTS).expect("pre-4c tokens read");
    assert_eq!(tokens.fonts, None);
    let back = serde_json::to_value(&tokens).expect("serialize");
    assert!(
        back.get("fonts").is_none(),
        "an absent block stays absent on the wire"
    );
}

// @internal
#[test]
fn a_fonts_block_round_trips_with_its_three_families() {
    let mut tokens: PresentationTokens = serde_json::from_str(WITHOUT_FONTS).expect("tokens read");
    tokens.fonts = Some(PresentationFonts {
        display: "Bricolage Grotesque".into(),
        body: "Hanken Grotesk".into(),
        mono: "JetBrains Mono".into(),
    });
    let json = serde_json::to_string(&tokens).expect("serialize");
    let back: PresentationTokens = serde_json::from_str(&json).expect("read back");
    assert_eq!(back, tokens);
    assert_eq!(
        back.fonts.as_ref().map(|f| f.mono.as_str()),
        Some("JetBrains Mono")
    );
}
