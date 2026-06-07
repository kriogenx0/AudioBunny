PLUGINS = [
  # ── Synths ──────────────────────────────────────────────────────────────
  { name: "Serum",         manufacturer: "Xfer Records",         plugin_type: "VST 3",
    description: "The most popular wavetable synthesizer. Drag-and-drop wavetable editing with a visual workflow.",
    version: "1.36", tags: "synth,wavetable,lead,bass", is_free: false, price_usd: 189.00 },
  { name: "Guitar Rig 7",  manufacturer: "Native Instruments",   plugin_type: "VST 3",
    description: "The ultimate amp and effects rack. 17 guitar amps, 27 cabinets, and 54 effects in one plugin.",
    version: "7.1.0", tags: "guitar,amp,effects,NI", is_free: false, price_usd: 299.00 },
  { name: "Massive X",     manufacturer: "Native Instruments",   plugin_type: "VST 3",
    description: "Next evolution of Massive. Phase modulation, formant filters, and dual oscillator routing.",
    version: "1.5.3", tags: "synth,wavetable,massive,NI", is_free: false, price_usd: 149.00 },
  { name: "Vital",         manufacturer: "Matt Tytel",           plugin_type: "VST 3",
    description: "Spectral warping wavetable synth. Free tier with 25 presets. Smooth modulation system.",
    version: "1.0.8", tags: "synth,wavetable,free,spectral", is_free: true },
  { name: "Surge XT",      manufacturer: "Surge Synth Team",     plugin_type: "VST 3",
    description: "Open-source hybrid synthesizer with subtractive, FM, and wavetable synthesis.",
    version: "1.3.4", tags: "synth,free,open-source,hybrid", is_free: true },
  { name: "Phase Plant",   manufacturer: "Kilohearts",           plugin_type: "VST 3",
    description: "Modular semi-modular synth. Mix and match synthesis in a single instrument.",
    version: "2.1.1", tags: "synth,modular", is_free: false, price_usd: 99.00 },
  { name: "ES2",           manufacturer: "Apple",                plugin_type: "Audio Unit",
    description: "Hybrid digital synthesizer bundled with Logic Pro.",
    version: "2.0", tags: "synth,hybrid,bundled,Logic", is_free: true },
  # ── Effects ─────────────────────────────────────────────────────────────
  { name: "FabFilter Pro-Q 3", manufacturer: "FabFilter",        plugin_type: "VST 3",
    description: "Professional mastering EQ with dynamic EQ modes and linear phase.",
    version: "3.22", tags: "eq,mastering,dynamics", is_free: false, price_usd: 179.00 },
  { name: "Valhalla VintageVerb", manufacturer: "Valhalla DSP",  plugin_type: "VST 3",
    description: "Classic hardware reverb algorithms from the 1970s–1980s. 17 algorithms.",
    version: "3.0.3", tags: "reverb,vintage,hardware-emulation", is_free: false, price_usd: 50.00 },
  { name: "Valhalla Supermassive", manufacturer: "Valhalla DSP", plugin_type: "VST 3",
    description: "Free reverb and delay effect for massive reverbs and echo effects.",
    version: "3.0.0", tags: "reverb,delay,free", is_free: true },
  { name: "OTT",           manufacturer: "Xfer Records",         plugin_type: "VST 3",
    description: "Free multiband upward/downward compressor — go-to for EDM sound design.",
    version: "1.31", tags: "compressor,multiband,free,EDM", is_free: true },
  { name: "Kontakt 7",     manufacturer: "Native Instruments",   plugin_type: "Audio Unit",
    description: "The industry-standard sampler. 65 GB library, hundreds of third-party instruments.",
    version: "7.10", tags: "sampler,NI,orchestral", is_free: false, price_usd: 399.00 },
].freeze

SERUM_PRESETS = [
  { name: "Supersaw Anthem",  author: "AudioBunny", genre: "Trance",
    description: "Thick detuned supersaw stack for epic trance anthems. Wide stereo spread with subtle LFO.",
    tags: "supersaw,trance,pad,wide,anthem", file_extension: "fxp" },
  { name: "Deep Sub Bass",    author: "AudioBunny", genre: "Bass",
    description: "Punchy 808-style sub bass with gentle saturation and sidechain-ready envelope.",
    tags: "sub,bass,808,punchy", file_extension: "fxp" },
  { name: "Pluck Garden",     author: "AudioBunny", genre: "Ambient",
    description: "Delicate pluck with long reverb tail. Perfect for lo-fi and ambient productions.",
    tags: "pluck,ambient,lofi,reverb", file_extension: "fxp" },
  { name: "Rave Chord Stack", author: "AudioBunny", genre: "Trance",
    description: "Classic rave chord stab with unison detune and quick envelope for hard trance.",
    tags: "chord,rave,trance,stab", file_extension: "fxp" },
  { name: "Neuro Wobble",     author: "AudioBunny", genre: "Dubstep",
    description: "Aggressive neuro bass with LFO-modulated filter and distortion chain.",
    tags: "neuro,wobble,dubstep,bass,aggressive", file_extension: "fxp" },
  { name: "Lush Pad",         author: "AudioBunny", genre: "Ambient",
    description: "Evolving pad with slow filter sweep and chorus. Fills the stereo field beautifully.",
    tags: "pad,lush,evolving,ambient,slow", file_extension: "fxp" },
  { name: "Techno Seq",       author: "AudioBunny", genre: "Techno",
    description: "Acidic sequence synth with fast envelope and drive. Works great at 130–145 BPM.",
    tags: "techno,acid,sequence,arp", file_extension: "fxp" },
  { name: "FX Riser",         author: "AudioBunny", genre: "FX",
    description: "Upward sweep with pitch and filter automation baked into the modulation matrix.",
    tags: "fx,riser,sweep,transition", file_extension: "fxp" },
  { name: "Dirty Lead",       author: "AudioBunny", genre: "Rock",
    description: "Hard clipped, distorted lead with feedback saturation and slight pitch wobble.",
    tags: "lead,rock,dirty,distorted", file_extension: "fxp" },
  { name: "Crystal Keys",     author: "AudioBunny", genre: "Pop",
    description: "Bright, glassy keys patch. Clean and sparkly, sits perfectly in the high mids.",
    tags: "keys,pop,bright,glassy,clean", file_extension: "fxp" },
].freeze

GUITAR_RIG_PRESETS = [
  { name: "Smooth Jazz Clean", author: "AudioBunny", genre: "Jazz",
    description: "Warm Fender-style clean with gentle chorus and spring reverb. Great for jazz chords.",
    tags: "clean,jazz,warm,chorus,fender", file_extension: "ngrr" },
  { name: "Texas Crunch",      author: "AudioBunny", genre: "Blues",
    description: "Texas blues crunch with tube compression and a hint of spring reverb.",
    tags: "crunch,blues,texas,tube,spring", file_extension: "ngrr" },
  { name: "Modern Metal",      author: "AudioBunny", genre: "Metal",
    description: "High-gain modern metal with tight low end and scooped mids. Drop-tune ready.",
    tags: "metal,high-gain,modern,tight", file_extension: "ngrr" },
  { name: "Stoner Fuzz",       author: "AudioBunny", genre: "Rock",
    description: "Thick vintage fuzz for stoner and doom riffs. Lots of sustain and warmth.",
    tags: "fuzz,stoner,doom,vintage,sustain", file_extension: "ngrr" },
  { name: "Ambient Space",     author: "AudioBunny", genre: "Ambient",
    description: "Clean with heavy reverb and delay. Transforms any chord into a soundscape.",
    tags: "ambient,reverb,delay,clean,atmospheric", file_extension: "ngrr" },
  { name: "Classic Rock Lead", author: "AudioBunny", genre: "Rock",
    description: "Plexi-style crunch with tube screamer in front. Marshall-in-a-box tone.",
    tags: "classic-rock,lead,plexi,marshall,crunch", file_extension: "ngrr" },
  { name: "Death Metal",       author: "AudioBunny", genre: "Metal",
    description: "Extreme gain Rectifier-style tone. Crushing palm mutes, razor-sharp leads.",
    tags: "death-metal,extreme,rectifier,palm-mute", file_extension: "ngrr" },
  { name: "Blues Sustain",     author: "AudioBunny", genre: "Blues",
    description: "Medium overdrive with a natural compression that makes leads sing with sustain.",
    tags: "blues,sustain,overdrive,natural", file_extension: "ngrr" },
].freeze

puts "Seeding plugins..."
Plugin.destroy_all

plugin_records = PLUGINS.each_with_object({}) do |attrs, h|
  p = Plugin.create!(attrs)
  h[p.name] = p
end
puts "  #{Plugin.count} plugins created."

puts "Seeding presets..."
Preset.destroy_all

serum       = plugin_records["Serum"]
guitar_rig  = plugin_records["Guitar Rig 7"]

SERUM_PRESETS.each       { |p| Preset.create!(p.merge(plugin: serum)) }
GUITAR_RIG_PRESETS.each  { |p| Preset.create!(p.merge(plugin: guitar_rig)) }
puts "  #{Preset.count} presets created."

puts "Done."
