enum Gender { women, men }

enum StyleCategory { all, wigs, braids, locs, curls, fades }

class HairStyle {
  final String name;
  final String nameKey; // translation key
  final String asset; // filename in assets/hairstyles/
  final String price; // FCFA
  final Gender gender;
  final StyleCategory category;
  final String description; // sent to AI for generation

  const HairStyle({
    required this.name,
    required this.nameKey,
    required this.asset,
    required this.price,
    required this.gender,
    required this.category,
    required this.description,
  });

  String get assetPath => 'assets/hairstyles/$asset';
}

class HairStyleCatalog {
  static const List<HairStyle> allStyles = [
    // ═══════════════════════════════════════════
    //  WOMEN — WIGS
    // ═══════════════════════════════════════════
    HairStyle(
      name: 'Curly Bob Wig',
      nameKey: 'styleCurlyBobWig',
      asset: 'curly bob wigs.png',
      price: '15,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Short curly bob wig, voluminous bouncy curls, chin-length, natural-looking with soft curls framing the face',
    ),
    HairStyle(
      name: 'Curly Pixie Wig',
      nameKey: 'styleCurlyPixieWig',
      asset: 'curly pixie wig.png',
      price: '12,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Short curly pixie cut wig, tight defined curls, cropped close to the head, chic and low-maintenance',
    ),
    HairStyle(
      name: 'Curly Ponytail Wig',
      nameKey: 'styleCurlyPonytailWig',
      asset: 'curly pony tail wig.png',
      price: '14,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Curly ponytail wig, high ponytail with voluminous spiral curls cascading down, elegant and playful',
    ),
    HairStyle(
      name: 'Half-Up Curly Wavy Wig',
      nameKey: 'styleHalfUpCurlyWavyWig',
      asset: 'half up curly long wavy wig.png',
      price: '18,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Long wavy wig with half-up style, top section pulled back while long loose waves flow past shoulders, romantic and versatile',
    ),
    HairStyle(
      name: 'Half-Up Pixie Curl Wig',
      nameKey: 'styleHalfUpPixieCurlWig',
      asset: 'halfup pixie curl long wig.png',
      price: '16,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Long wig with pixie curls and half-up styling, defined curls with front section pinned back, sophisticated look',
    ),
    HairStyle(
      name: 'Middle Part Bob Wig',
      nameKey: 'styleMiddlePartBobWig',
      asset: 'middle part straight bob wig.png',
      price: '13,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Straight bob wig with clean middle part, sleek and polished, chin to shoulder length, sharp cut ends',
    ),
    HairStyle(
      name: 'Pixie Curl Long Wig',
      nameKey: 'stylePixieCurlLongWig',
      asset: 'pixie curl long wig.png',
      price: '17,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Long pixie curl wig, defined tight curls flowing past shoulders, full volume, glamorous texture',
    ),
    HairStyle(
      name: 'Pixie Curl Ponytail Wig',
      nameKey: 'stylePixieCurlPonytailWig',
      asset: 'pixie curl pony tail wig.png',
      price: '15,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Pixie curl wig styled into a high ponytail, tight curls gathered at the crown, trendy and bold',
    ),
    HairStyle(
      name: 'Side Part Bob Wig',
      nameKey: 'styleSidePartBobWig',
      asset: 'side part straight bob wig.png',
      price: '13,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Straight bob wig with deep side part, asymmetric drape, sleek and modern, one side tucked behind ear',
    ),
    HairStyle(
      name: 'Simple Ponytail Wig',
      nameKey: 'styleSimplePonytailWig',
      asset: 'simple pony tail wig.png',
      price: '10,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Simple straight ponytail wig, low or mid ponytail, clean and sleek, everyday natural look',
    ),
    HairStyle(
      name: 'Wavy Bob Wig',
      nameKey: 'styleWavyBobWig',
      asset: 'wavy bob wig.png',
      price: '14,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Wavy bob wig, loose beach waves at chin to shoulder length, effortlessly chic and tousled texture',
    ),
    HairStyle(
      name: 'Wavy Long Wig',
      nameKey: 'styleWavyLongWig',
      asset: 'wavy long wig.png',
      price: '20,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Long flowing wavy wig, cascading waves past mid-back, glamorous red-carpet volume, soft texture',
    ),
    HairStyle(
      name: 'Wavy Pixie Wig',
      nameKey: 'styleWavyPixieWig',
      asset: 'wavy pixie wig.png',
      price: '11,000',
      gender: Gender.women,
      category: StyleCategory.wigs,
      description:
          'Short wavy pixie wig, textured waves cropped close, playful and modern, easy to wear',
    ),

    // ═══════════════════════════════════════════
    //  WOMEN — BRAIDS
    // ═══════════════════════════════════════════
    HairStyle(
      name: 'Boho Braids Long',
      nameKey: 'styleBohoBraidsLong',
      asset: 'boho braids long.png',
      price: '20,000',
      gender: Gender.women,
      category: StyleCategory.braids,
      description:
          'Long bohemian braids with loose curly ends, waist-length, boho goddess braids with wispy curls interspersed',
    ),
    HairStyle(
      name: 'Boho Braids Short',
      nameKey: 'styleBohoBraidsShort',
      asset: 'boho braids short.png',
      price: '15,000',
      gender: Gender.women,
      category: StyleCategory.braids,
      description:
          'Short bohemian braids with curly ends, shoulder-length, boho braids with loose curly pieces mixed in',
    ),
    HairStyle(
      name: 'Boho Cornrow',
      nameKey: 'styleBohoCornrow',
      asset: 'boho conrail.png',
      price: '12,000',
      gender: Gender.women,
      category: StyleCategory.braids,
      description:
          'Bohemian cornrow braids, feed-in cornrows with loose curly strands, artistic and free-spirited pattern',
    ),
    HairStyle(
      name: 'Boho Ponytail Braids',
      nameKey: 'styleBohoPonytailBraids',
      asset: 'boho pony tail braids.png',
      price: '18,000',
      gender: Gender.women,
      category: StyleCategory.braids,
      description:
          'Bohemian braids gathered into a high ponytail, braids with curly boho ends flowing from ponytail',
    ),
    HairStyle(
      name: 'Knotless Braids Long',
      nameKey: 'styleKnotlessBraidsLong',
      asset: 'knotless briads long.png',
      price: '22,000',
      gender: Gender.women,
      category: StyleCategory.braids,
      description:
          'Long knotless box braids, waist-length, seamless feed-in technique, neat and uniform, lightweight tension-free braids',
    ),
    HairStyle(
      name: 'Knotless Braids Short',
      nameKey: 'styleKnotlessBraidsShort',
      asset: 'knotless briads short.png',
      price: '15,000',
      gender: Gender.women,
      category: StyleCategory.braids,
      description:
          'Short knotless box braids, shoulder-length, seamless starts, neat partings, lightweight protective style',
    ),
    HairStyle(
      name: 'Lemonade Braids',
      nameKey: 'styleLemonadeBraids',
      asset: 'lemonade.png',
      price: '18,000',
      gender: Gender.women,
      category: StyleCategory.braids,
      description:
          'Lemonade side-swept braids (Beyoncé-inspired), all braids swept to one side, cornrow feed-in pattern',
    ),
    HairStyle(
      name: 'Patewo Braids',
      nameKey: 'stylePatewoBraids',
      asset: 'patewo braids.png',
      price: '10,000',
      gender: Gender.women,
      category: StyleCategory.braids,
      description:
          'Patewo braids (Nigerian-style all-back braids), straight-back braids gathered neatly at the nape, traditional and clean',
    ),
    HairStyle(
      name: 'Up-Do Braids',
      nameKey: 'styleUpDoBraids',
      asset: 'simple up do braids.png',
      price: '16,000',
      gender: Gender.women,
      category: StyleCategory.braids,
      description:
          'Braided updo hairstyle, braids gathered and pinned up into an elegant bun or high updo, formal and sophisticated',
    ),
    HairStyle(
      name: 'Simple Cornrow Style 2',
      nameKey: 'styleSimpleCornrow2',
      asset: 'simplecornrow2.png',
      price: '8,000',
      gender: Gender.women,
      category: StyleCategory.braids,
      description:
          'Simple cornrow pattern variation, geometric or curved cornrow design braided close to the scalp',
    ),

    // ═══════════════════════════════════════════
    //  WOMEN — LOCS
    // ═══════════════════════════════════════════
    HairStyle(
      name: 'Locs Long',
      nameKey: 'styleLocsLong',
      asset: 'locs long.png',
      price: '25,000',
      gender: Gender.women,
      category: StyleCategory.locs,
      description:
          'Long faux locs, waist-length dreadlocks, thick or medium-width locs hanging freely, natural bohemian vibe',
    ),
    HairStyle(
      name: 'Locs Medium',
      nameKey: 'styleLocsMedium',
      asset: 'locs medium.png',
      price: '20,000',
      gender: Gender.women,
      category: StyleCategory.locs,
      description:
          'Medium-length faux locs, shoulder to chest length, neat uniform locs with natural texture',
    ),
    HairStyle(
      name: 'Locs Short',
      nameKey: 'styleLocsShort',
      asset: 'locs short.png',
      price: '15,000',
      gender: Gender.women,
      category: StyleCategory.locs,
      description:
          'Short faux locs, bob-length dreadlocks, chin to shoulder length, edgy and manageable',
    ),

    // ═══════════════════════════════════════════
    //  WOMEN — CURLS
    // ═══════════════════════════════════════════
    HairStyle(
      name: 'French Curl Long',
      nameKey: 'styleFrenchCurlLong',
      asset: 'french curl long.png',
      price: '22,000',
      gender: Gender.women,
      category: StyleCategory.curls,
      description:
          'Long French curl crochet braids, tight spiral curls flowing past shoulders, voluminous bouncy texture',
    ),
    HairStyle(
      name: 'French Curls Short',
      nameKey: 'styleFrenchCurlsShort',
      asset: 'french curls short.png',
      price: '16,000',
      gender: Gender.women,
      category: StyleCategory.curls,
      description:
          'Short French curl crochet style, chin-length tight spiral curls, full and bouncy, playful look',
    ),
    HairStyle(
      name: 'Jadawada',
      nameKey: 'styleJadawada',
      asset: 'jadawada.png',
      price: '18,000',
      gender: Gender.women,
      category: StyleCategory.curls,
      description:
          'Jadawada curls style, unique defined curly pattern, voluminous textured curls with natural movement',
    ),

    // ═══════════════════════════════════════════
    //  MEN — FADES
    // ═══════════════════════════════════════════
    HairStyle(
      name: 'Buzz Cut Low Fade',
      nameKey: 'styleBuzzCutLowFade',
      asset: 'MEN/men1.jpeg',
      price: '3,000',
      gender: Gender.men,
      category: StyleCategory.fades,
      description:
          'Short buzz cut with a clean low skin fade, tight textured crop on top, sharp lineup at the forehead and temples, minimal length with precision edges',
    ),
    HairStyle(
      name: 'Mid Taper Fade',
      nameKey: 'styleMidTaperFade',
      asset: 'MEN/men2.jpeg',
      price: '3,500',
      gender: Gender.men,
      category: StyleCategory.fades,
      description:
          'Classic mid taper fade, skin-tight sides blending gradually into a short textured top, clean neckline taper, barber-fresh finish',
    ),
    HairStyle(
      name: '360 Waves with Beard',
      nameKey: 'style360WavesBeard',
      asset: 'MEN/men5.jpeg',
      price: '4,000',
      gender: Gender.men,
      category: StyleCategory.fades,
      description:
          '360 wave pattern with deep defined waves all around, mid skin fade on the sides, sharp lineup, paired with a full thick beard, clean and distinguished',
    ),
    HairStyle(
      name: '360 Waves Low Fade',
      nameKey: 'style360WavesLowFade',
      asset: 'MEN/men6.jpeg',
      price: '3,500',
      gender: Gender.men,
      category: StyleCategory.fades,
      description:
          'Clean 360 wave pattern on top with a low skin fade, sharp temple and forehead lineup, waves flowing in a defined spiral pattern, neat and polished',
    ),

    // ═══════════════════════════════════════════
    //  MEN — CURLS
    // ═══════════════════════════════════════════
    HairStyle(
      name: 'Curly Top Drop Fade',
      nameKey: 'styleCurlyTopDropFade',
      asset: 'MEN/men3.jpeg',
      price: '4,500',
      gender: Gender.men,
      category: StyleCategory.curls,
      description:
          'High curly top with a drop fade, voluminous defined coils on top, tapered sides fading to skin behind the ear, full shaped beard with clean edges',
    ),
    HairStyle(
      name: 'Curly High Top Fade',
      nameKey: 'styleCurlyHighTopFade',
      asset: 'MEN/men4.jpeg',
      price: '4,000',
      gender: Gender.men,
      category: StyleCategory.curls,
      description:
          'High top with tight defined curls, mid skin fade on the sides, sharp square lineup at the forehead, voluminous curly texture on top with height and definition',
    ),

    // ═══════════════════════════════════════════
    //  MEN — AFRO
    // ═══════════════════════════════════════════
    HairStyle(
      name: 'Natural Afro',
      nameKey: 'styleNaturalAfro',
      asset: 'MEN/natural_afro.jpg',
      price: '2,000',
      gender: Gender.men,
      category: StyleCategory.curls,
      description:
          'Full natural afro, big rounded shape with voluminous coily texture, free-form pick-out afro with height and width, classic African natural hairstyle',
    ),

    // ═══════════════════════════════════════════
    //  MEN — BRAIDS
    // ═══════════════════════════════════════════
    HairStyle(
      name: 'Cornrows',
      nameKey: 'styleMenCornrows',
      asset: 'MEN/cornrows.jpg',
      price: '5,000',
      gender: Gender.men,
      category: StyleCategory.braids,
      description:
          'Men\'s cornrow braids, straight-back rows braided tight to the scalp, clean parallel lines from forehead to nape, classic African men\'s braided style',
    ),

    // ═══════════════════════════════════════════
    //  MEN — LOCS
    // ═══════════════════════════════════════════
    HairStyle(
      name: 'Short Locs',
      nameKey: 'styleShortLocsMen',
      asset: 'MEN/short_locs.jpg',
      price: '8,000',
      gender: Gender.men,
      category: StyleCategory.locs,
      description:
          'Men\'s short to medium freeform dreadlocks, shoulder-length locs with natural texture, loose hanging style, popular African men\'s loc look',
    ),

    // ═══════════════════════════════════════════
    //  MEN — MORE FADES
    // ═══════════════════════════════════════════
    HairStyle(
      name: 'Skin Fade',
      nameKey: 'styleSkinFade',
      asset: 'MEN/skin_fade.jpg',
      price: '3,000',
      gender: Gender.men,
      category: StyleCategory.fades,
      description:
          'Clean skin fade with short textured top, sides faded down to skin, sharp beard lineup, fresh barbershop finish, popular West African barber cut',
    ),
    HairStyle(
      name: 'Tapered Curly Top',
      nameKey: 'styleTaperedCurlyTop',
      asset: 'MEN/mohawk_fade.jpg',
      price: '3,500',
      gender: Gender.men,
      category: StyleCategory.fades,
      description:
          'Tapered sides with curly textured top, short tight curls on top with faded sides, modern African barber style with clean edges',
    ),
    HairStyle(
      name: 'Finger Waves & Beard',
      nameKey: 'styleFingerWavesBeard',
      asset: 'MEN/twists.jpg',
      price: '4,500',
      gender: Gender.men,
      category: StyleCategory.fades,
      description:
          'Defined finger wave pattern on top with a full shaped beard, deep wave sculpting with clean edges, stylish and polished African men\'s wave style',
    ),
  ];

  /// Get styles filtered by gender.
  static List<HairStyle> byGender(Gender gender) =>
      allStyles.where((s) => s.gender == gender).toList();

  /// Get styles filtered by gender and category.
  static List<HairStyle> filter(Gender gender, StyleCategory category) {
    if (category == StyleCategory.all) return byGender(gender);
    return allStyles
        .where((s) => s.gender == gender && s.category == category)
        .toList();
  }

  /// Get available categories for a gender (only those with styles).
  static List<StyleCategory> categoriesFor(Gender gender) {
    final cats = <StyleCategory>{};
    for (final s in allStyles) {
      if (s.gender == gender) cats.add(s.category);
    }
    // Always include 'all' first
    return [StyleCategory.all, ...cats];
  }
}
