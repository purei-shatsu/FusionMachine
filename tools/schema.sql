-- Digimon card database, extracted from DCGO (see tools/dcgo_import.py).
-- Lossless: every native Digimon field is preserved. Raw ints are stored as-is,
-- with derived names alongside them so a bad mapping is a one-line fix.

CREATE TABLE IF NOT EXISTS cards (
    card_id             TEXT PRIMARY KEY,   -- 'BT1-038'
    set_code            TEXT NOT NULL,      -- 'BT1'
    card_number         INTEGER,            -- 38
    name_en             TEXT NOT NULL,
    name_jp             TEXT,
    card_kind           INTEGER NOT NULL,   -- 0 Digimon, 1 Tamer, 2 Option, 3 DigiEgg
    card_kind_name      TEXT,
    level               INTEGER,            -- 0 when n/a (Tamer/Option)
    dp                  INTEGER,
    play_cost           INTEGER,            -- -1 when n/a
    rarity              INTEGER,
    overflow_memory     INTEGER,
    link_dp             INTEGER,
    link_effect         TEXT,
    link_requirement    TEXT,
    max_in_deck         INTEGER,
    effect_en           TEXT,
    inherited_effect_en TEXT,
    security_effect_en  TEXT,
    sprite_name         TEXT,               -- CardSpriteName
    image_file          TEXT,               -- '<CardID>.webp', or NULL when no art exists
    has_art             INTEGER NOT NULL,
    source_path         TEXT NOT NULL,      -- .asset path relative to CardBaseEntity
    source_hash         TEXT NOT NULL,      -- sha1 of the .asset; drives incremental update
    updated_at          TEXT NOT NULL
);

-- Release order of every set, so "newer card wins" is answerable. Nothing in the
-- DCGO assets carries a date, and rowid is useless (the importer walks folders
-- alphabetically, so BT10 lands before BT2). Populated from SET_RELEASES in
-- tools/dcgo_import.py.
CREATE TABLE IF NOT EXISTS sets (
    set_code      TEXT PRIMARY KEY,
    release_order INTEGER NOT NULL,
    release_date  TEXT                -- NULL for the undated promo lines (P, LM)
);

CREATE TABLE IF NOT EXISTS card_colors (
    card_id    TEXT NOT NULL,
    ord        INTEGER NOT NULL,
    color      INTEGER NOT NULL,
    color_name TEXT,
    PRIMARY KEY (card_id, ord),
    FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS card_types (
    card_id TEXT NOT NULL,
    ord     INTEGER NOT NULL,
    type_en TEXT NOT NULL,
    PRIMARY KEY (card_id, ord),
    FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE
);

-- Stage (Form_ENG), e.g. 'Rookie', 'Ultimate'. Usually one, but some cards carry
-- two (BT18-102 is both 'Mega' and 'Hybrid'), hence a table rather than a column.
CREATE TABLE IF NOT EXISTS card_forms (
    card_id TEXT NOT NULL,
    ord     INTEGER NOT NULL,
    form_en TEXT NOT NULL,
    PRIMARY KEY (card_id, ord),
    FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE
);

-- 'Vaccine' | 'Data' | 'Virus' | 'Free'. A few cards have two (BT16-102 is Vaccine + Free).
CREATE TABLE IF NOT EXISTS card_attributes (
    card_id      TEXT NOT NULL,
    ord          INTEGER NOT NULL,
    attribute_en TEXT NOT NULL,
    PRIMARY KEY (card_id, ord),
    FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE
);

-- Structured digivolution requirements: "from a level <from_level> <from_color_name>
-- Digimon, digivolve into this card for <memory_cost> memory".
CREATE TABLE IF NOT EXISTS card_evo_costs (
    card_id         TEXT NOT NULL,
    ord             INTEGER NOT NULL,
    from_color      INTEGER,
    from_color_name TEXT,
    from_level      INTEGER,
    memory_cost     INTEGER,
    PRIMARY KEY (card_id, ord),
    FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_cards_kind_level ON cards(card_kind, level);
CREATE INDEX IF NOT EXISTS idx_cards_set        ON cards(set_code);
CREATE INDEX IF NOT EXISTS idx_evo_from         ON card_evo_costs(from_color, from_level);
