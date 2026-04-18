"""Seed the database with sample audio plugins."""
from sqlmodel import Session, select
from database import engine, create_db_and_tables
from models import Plugin

PLUGINS = [
    # ── Synths ──────────────────────────────────────────────────────────────
    dict(
        name="Serum",
        manufacturer="Xfer Records",
        plugin_type="VST 3",
        description="The most popular wavetable synthesizer. Drag-and-drop wavetable editing, a visual and creative workflow-oriented interface.",
        version="1.36",
        tags="synth,wavetable,lead,bass",
        thumbnail_url="/thumbnails/serum.png",
        is_free=False,
        price_usd=189.00,
    ),
    dict(
        name="Massive X",
        manufacturer="Native Instruments",
        plugin_type="VST 3",
        description="The next evolution of the legendary Massive synthesizer. Phase modulation, formant filters, and dual oscillator routing.",
        version="1.5.3",
        tags="synth,wavetable,massive,NI",
        thumbnail_url="/thumbnails/massivex.png",
        is_free=False,
        price_usd=149.00,
    ),
    dict(
        name="Vital",
        manufacturer="Matt Tytel",
        plugin_type="VST 3",
        description="Spectral warping wavetable synth. Free tier available with 25 presets. Smooth modulation system.",
        version="1.0.8",
        tags="synth,wavetable,free,spectral",
        thumbnail_url="/thumbnails/vital.png",
        is_free=True,
    ),
    dict(
        name="Surge XT",
        manufacturer="Surge Synth Team",
        plugin_type="VST 3",
        description="Open-source hybrid synthesizer with subtractive, FM, and wavetable synthesis. 100% free.",
        version="1.3.4",
        tags="synth,free,open-source,hybrid",
        thumbnail_url="/thumbnails/surge.png",
        is_free=True,
    ),
    dict(
        name="Phase Plant",
        manufacturer="Kilohearts",
        plugin_type="VST 3",
        description="Modular semi-modular synth. Mix and match synthesis techniques in a single instrument.",
        version="2.1.1",
        tags="synth,modular,semi-modular",
        thumbnail_url="/thumbnails/phaseplant.png",
        is_free=False,
        price_usd=99.00,
    ),
    dict(
        name="ES2",
        manufacturer="Apple",
        plugin_type="Audio Unit",
        description="Hybrid digital synthesizer bundled with Logic Pro. Triangle, square, sine, and sawtooth oscillators with FM.",
        version="2.0",
        tags="synth,hybrid,bundled,Logic",
        thumbnail_url="/thumbnails/es2.png",
        is_free=True,
    ),
    dict(
        name="Helm",
        manufacturer="Matt Tytel",
        plugin_type="Audio Unit",
        description="Free, cross-platform polyphonic synthesizer with a powerful modulation system.",
        version="0.9.0",
        tags="synth,free,polyphonic",
        thumbnail_url="/thumbnails/helm.png",
        is_free=True,
    ),

    # ── Effects ─────────────────────────────────────────────────────────────
    dict(
        name="FabFilter Pro-Q 3",
        manufacturer="FabFilter",
        plugin_type="VST 3",
        description="Professional mastering EQ with dynamic EQ modes, linear phase, and a natural phase mode.",
        version="3.22",
        tags="eq,mastering,dynamics",
        thumbnail_url="/thumbnails/proq3.png",
        is_free=False,
        price_usd=179.00,
    ),
    dict(
        name="Valhalla VintageVerb",
        manufacturer="Valhalla DSP",
        plugin_type="VST 3",
        description="Classic hardware reverb algorithms from the 1970s–1980s. 17 algorithms, minimal CPU.",
        version="3.0.3",
        tags="reverb,vintage,hardware-emulation",
        thumbnail_url="/thumbnails/valhallavv.png",
        is_free=False,
        price_usd=50.00,
    ),
    dict(
        name="Valhalla Room",
        manufacturer="Valhalla DSP",
        plugin_type="VST 3",
        description="Algorithmic reverb covering small rooms to large halls. 12 room modes.",
        version="1.1.2",
        tags="reverb,room,algorithmic",
        thumbnail_url="/thumbnails/valhallaroom.png",
        is_free=False,
        price_usd=50.00,
    ),
    dict(
        name="Valhalla Supermassive",
        manufacturer="Valhalla DSP",
        plugin_type="VST 3",
        description="Free reverb and delay effect designed for massive reverbs and echo effects.",
        version="3.0.0",
        tags="reverb,delay,free",
        thumbnail_url="/thumbnails/supermassive.png",
        is_free=True,
    ),
    dict(
        name="FabFilter Pro-C 2",
        manufacturer="FabFilter",
        plugin_type="VST 3",
        description="Professional compressor with 8 compression styles from clean to pumping mastering comp.",
        version="2.14",
        tags="compressor,mastering,dynamics",
        thumbnail_url="/thumbnails/proc2.png",
        is_free=False,
        price_usd=179.00,
    ),
    dict(
        name="OTT",
        manufacturer="Xfer Records",
        plugin_type="VST 3",
        description="Free multiband upward/downward compressor — go-to for EDM sound design.",
        version="1.31",
        tags="compressor,multiband,free,EDM",
        thumbnail_url="/thumbnails/ott.png",
        is_free=True,
    ),
    dict(
        name="Izotope Ozone 11",
        manufacturer="iZotope",
        plugin_type="Audio Unit",
        description="AI-assisted mastering suite. Includes EQ, limiter, imager, dynamics, and vintage tape.",
        version="11.0",
        tags="mastering,AI,suite,EQ,limiter",
        thumbnail_url="/thumbnails/ozone11.png",
        is_free=False,
        price_usd=249.00,
    ),
    dict(
        name="Soundtoys 5",
        manufacturer="Soundtoys",
        plugin_type="VST 2",
        description="Creative effects bundle: EchoBoy, PanMan, Crystallizer, Tremolator, and more.",
        version="5.4.3",
        tags="bundle,creative,delay,modulation",
        thumbnail_url="/thumbnails/soundtoys5.png",
        is_free=False,
        price_usd=399.00,
    ),
    dict(
        name="SPAN",
        manufacturer="Voxengo",
        plugin_type="VST 3",
        description="Free real-time FFT spectrum analyzer. Highly accurate, low CPU, professional metering.",
        version="3.17",
        tags="analyzer,metering,free,utility",
        thumbnail_url="/thumbnails/span.png",
        is_free=True,
    ),

    # ── Drums & Samplers ────────────────────────────────────────────────────
    dict(
        name="Battery 4",
        manufacturer="Native Instruments",
        plugin_type="VST 3",
        description="Drum machine and sampler with 130+ kits, per-pad effects chain and modulation.",
        version="4.3.0",
        tags="drums,sampler,NI,kits",
        thumbnail_url="/thumbnails/battery4.png",
        is_free=False,
        price_usd=199.00,
    ),
    dict(
        name="Sitala",
        manufacturer="Decomposer",
        plugin_type="VST 3",
        description="Simple, free drum plugin — 16-pad sampler with per-pad EQ, compression, and reverb.",
        version="1.0.8",
        tags="drums,sampler,free,16-pad",
        thumbnail_url="/thumbnails/sitala.png",
        is_free=True,
    ),
    dict(
        name="Kontakt 7",
        manufacturer="Native Instruments",
        plugin_type="Audio Unit",
        description="The industry-standard sampler. 65 GB library, hundreds of third-party instruments.",
        version="7.10",
        tags="sampler,NI,orchestral,industry-standard",
        thumbnail_url="/thumbnails/kontakt7.png",
        is_free=False,
        price_usd=399.00,
    ),
    dict(
        name="DrumBrute Impact",
        manufacturer="Arturia",
        plugin_type="VST 3",
        description="Software emulation of the DrumBrute Impact analog drum machine. 10 drum voices.",
        version="1.2",
        tags="drums,analog,emulation,Arturia",
        thumbnail_url="/thumbnails/drumbrute.png",
        is_free=False,
        price_usd=99.00,
    ),
    dict(
        name="Drum Pro",
        manufacturer="StudioLinkedVST",
        plugin_type="VST 2",
        description="Free 24-part drum machine with dedicated envelopes and tuning per pad.",
        version="1.0",
        tags="drums,free,24-part",
        thumbnail_url="/thumbnails/drumpro.png",
        is_free=True,
    ),
]


def seed():
    create_db_and_tables()
    with Session(engine) as session:
        existing = session.exec(select(Plugin)).all()
        if existing:
            print(f"Database already has {len(existing)} plugins — skipping seed.")
            return
        for data in PLUGINS:
            session.add(Plugin(**data))
        session.commit()
        print(f"Seeded {len(PLUGINS)} plugins.")


if __name__ == "__main__":
    seed()
