// slivar JS helpers + mode-of-inheritance (MoI) tag functions.
//
// Loaded by `slivar expr --js` from conf/slivar.config. The config file calls
// the moi_*(fam) functions defined at the bottom of this file; everything
// above them is the building blocks.
//
// Family-structure handling:
//   - de novo (autosomal & X-linked) self-gates to trios because
//     segregating_denovo / segregating_denovo_x require both parents in `s`.
//   - dominant (autosomal & X-linked) is gated by has_aff_parent(fam)
//     so it doesn't fire on de novo events (kid het + parents hom_ref).
//   - recessive accepts any family structure where `fam.every(segregating_*)`
//     passes. With strict carrier rules below, that's trios, duos with the
//     informative parent, single-parent + sibling families, and solos.
//   - het_side covers compound-het detection for any non-trio family; trios
//     use the transmission-aware comphet_side(kid, mom, dad) via --trio.

// ---------------------------------------------------------------------------
// Quality config + hq filters
// ---------------------------------------------------------------------------
var config = {min_GQ: 20, min_AB: 0.20, min_DP: 6, min_male_X_GQ: 10, min_male_X_DP: 6}

function hq(kid, mom, dad, isX) {
  return hq1(kid, isX) && hq1(mom, isX) && hq1(dad, isX)
}

function hq1(sample, isX) {
  var gq = isX && sample.sex == 'male' ? config.min_male_X_GQ : config.min_GQ
  var dp = isX && sample.sex == 'male' ? config.min_male_X_DP : config.min_DP

  if (sample.unknown || (sample.GQ < gq)) return false;
  if ((sample.AD[0] + sample.AD[1]) < dp) return false;
  if (sample.hom_ref) return sample.AB < 0.02
  if (sample.het)     return sample.AB >= config.min_AB && sample.AB <= (1 - config.min_AB)
  return sample.AB > 0.98
}


// ---------------------------------------------------------------------------
// Trio-style compound-het helpers
// ---------------------------------------------------------------------------
// Used by `--trio 'comphet_side:comphet_side(kid, mom, dad)'` in slivar.config.

// True iff `sample` looks like one side of a compound het in isolation.
function solo_ch_het_side(sample) {
  return sample.het && hq1(sample)
}

// Standard slivar trio comphet_side: kid het, parents asymmetric (one het
// one hom_ref) so we can pin which parent the variant came from, and
// neither parent hom_alt (clinical heuristic: an unaffected hom_alt parent
// is strong evidence the variant isn't pathogenic enough to be a comphet side).
function comphet_side(kid, mom, dad) {
  return kid.het
      && (solo_ch_het_side(mom) != solo_ch_het_side(dad))
      && mom.alts != 2 && dad.alts != 2
      && solo_ch_het_side(kid) && hq1(mom) && hq1(dad);
}


// ---------------------------------------------------------------------------
// Per-sample segregation predicates (called via fam.every(...))
// ---------------------------------------------------------------------------
// Each function takes ONE family member `s` and returns true iff that member's
// genotype is consistent with the MoI. fam.every(seg_*) then aggregates across
// the whole family. Slivar populates s.mom, s.dad, s.kids based on the PED.

// --- de novo (autosomal) ---
function segregating_denovo(s) {
  if (!hq1(s)) return false;
  if (!s.affected) return s.hom_ref;
  if (s.hom_alt) return false;
  if (!(s.het && s.AB >= config.min_AB && s.AB <= (1 - config.min_AB))) return false;
  // Both parents must be present in the family -- de novo isn't provable otherwise.
  return ("mom" in s) && ("dad" in s);
}

// --- recessive (autosomal) ---
// Affected      => hom_alt
// Unaffected parent => MUST be het (carrier). hom_ref violates Mendelian
//                     inheritance given an affected hom_alt child.
// Unaffected non-parent (sibling) => het OR hom_ref (both Mendelian).
function segregating_recessive(s) {
  if (!hq1(s)) return false;
  if (variant.CHROM == "chrX" || variant.CHROM == "X") return segregating_recessive_x(s);
  if (s.affected) return s.hom_alt;
  // Unaffected: stricter rule for parents, permissive for sibs.
  if (s.kids && s.kids.length > 0) return s.het;
  return s.het || s.hom_ref;
}

// --- dominant (autosomal) ---
// Affected   => het OR hom_alt   (homozygous-affected for a dominant variant is
//                                  biologically possible, e.g. when both parents
//                                  are het carriers; matches GE's
//                                  InheritedAutosomalDominant filter)
// Unaffected => hom_ref (strict, including AB < 0.01 to exclude noisy hom_refs)
// Note: this function alone does NOT enforce "an affected parent exists" --
// that's done at the moi_dominant(fam) level via has_aff_parent(fam),
// otherwise this rule would also accept de novo events.
function segregating_dominant(s) {
  if (variant.CHROM == "chrX" || variant.CHROM == "X") return segregating_dominant_x(s);
  if (!hq1(s)) return false;
  if (s.affected) return s.het || s.hom_alt;
  return s.hom_ref && s.AB < 0.01;
}

// --- X-linked predicates (delegated to from the autosomal ones) ---
function hom_ref(s)        { return s && s.hom_ref && hq1(s); }
function hom_ref_parent(s) { return ("dad" in s) && s.dad.hom_ref && ("mom" in s) && s.mom.hom_ref; }

function segregating_recessive_x(s) {
  if (s.sex == "female") return s.affected == s.hom_alt;
  if (s.sex == "male") {
    if (s.affected && s.het && hom_ref_parent(s)) return false;  // ambiguous hemizygous
    return s.affected == (s.het || s.hom_alt);
  }
  return false;
}

function parents_x_dn_or_homref(s) {
  if (!("mom" in s) || !("dad" in s)) return false;
  return (hom_ref(s.mom) || segregating_denovo_x(s.mom))
      && (hom_ref(s.dad) || segregating_denovo_x(s.dad));
}

function segregating_denovo_x(s) {
  if (s.sex == "female") {
    if (s.affected) return s.het && hq1(s) && parents_x_dn_or_homref(s);
    return s.hom_ref;
  }
  if (s.sex == "male") {
    if (s.affected) return (s.het || s.hom_alt) && parents_x_dn_or_homref(s);
    return s.hom_ref;
  }
  return false;
}

function segregating_dominant_x(s) {
  if (!s.affected) return hq1(s, true) && s.hom_ref;

  if (s.sex == "male") {
    for (var i=0; i < s.kids.length; i++) {
      if (!s.kids[i].affected) return false;       // kids of affected dad must be affected
    }
    if (("mom" in s) && !(s.mom.affected == s.mom.het)) return false;
    if (("mom" in s) && !hq1(s.mom, true)) return false;
    if (("dad" in s) && !hq1(s.dad, true)) return false;
    return (s.hom_alt || s.het) && hq1(s, true);
  }

  if (s.sex != "female") return false;
  // Female: inherited dominant only -- de novos on chrX are handled by segregating_denovo_x.
  if (("mom" in s) || ("dad" in s)) {
    if (!((("mom" in s) && s.mom.affected && s.mom.het)
       || (("dad" in s) && s.dad.affected && s.dad.het))) return false;
    if (("dad" in s) && !hq1(s.dad, true)) return false;
    if (("mom" in s) && !hq1(s.mom, true)) return false;
  }
  return s.het && hq1(s, true);
}


// ---------------------------------------------------------------------------
// Family-level helpers
// ---------------------------------------------------------------------------
function is_autosomal() { return variant.CHROM !== "X" && variant.CHROM !== "chrX"; }
function is_x_linked()  { return variant.CHROM === "X" || variant.CHROM === "chrX"; }

// True iff any family member is BOTH affected AND has children in the
// family (i.e. they're an affected parent we observe). Gates `dominant` /
// `x_dominant` so they don't fire on de novo configurations.
function has_aff_parent(fam) {
  for (var i=0; i<fam.length; i++) {
    var s = fam[i];
    if (s.affected && s.kids && s.kids.length > 0) return true;
  }
  return false;
}

// True iff any affected family member is hq-het. Used by moi_het_side.
function proband_het(fam) {
  for (var i=0; i<fam.length; i++) {
    var s = fam[i];
    if (s.affected && s.het && hq1(s)) return true;
  }
  return false;
}

// True iff any UNAFFECTED PARENT in the family is hom_alt. Used to drop
// duo het_side candidates that wouldn't be a plausible disease-causing
// comphet side (mirrors the mom.alts != 2 && dad.alts != 2 rule in
// the trio comphet_side function).
function present_parent_hom_alt(fam) {
  for (var i=0; i<fam.length; i++) {
    var s = fam[i];
    if (s.affected) continue;
    if (!(s.kids && s.kids.length > 0)) continue;  // skip non-parents (siblings)
    if (s.hom_alt && hq1(s)) return true;
  }
  return false;
}

// True iff the affected proband has both parents in the family. Used to
// route compound-hets: trios use --trio comphet_side (transmission-aware);
// everything else uses moi_het_side.
function proband_has_both_parents(fam) {
  for (var i=0; i<fam.length; i++) {
    var s = fam[i];
    if (s.affected && ("mom" in s) && ("dad" in s)) return true;
  }
  return false;
}

// True iff this is a solo: the only family member is the affected proband.
// Single-variant MoI tags (recessive, x_recessive) are suppressed for solos
// because a solo provides zero segregation evidence -- the variant being in
// the proband's VCF is the only signal. Compound-het detection is still
// allowed (via moi_het_side) since paired hets in the same gene give some
// per-pair information.
function is_solo(fam) {
  return fam.length === 1 && fam[0].affected;
}


// ---------------------------------------------------------------------------
// Mode-of-inheritance tag functions
// ---------------------------------------------------------------------------
// One named function per --family-expr tag in conf/slivar.config. Each one
// fully encodes the chromosome guard + family-level gate + per-sample
// segregation check for that tag. The AF clause stays in slivar.config
// because it depends on Nextflow params.

function moi_denovo(fam)      { return is_autosomal() && fam.every(segregating_denovo); }
function moi_recessive(fam)   { return is_autosomal() && !is_solo(fam) && fam.every(segregating_recessive); }
function moi_dominant(fam)    { return is_autosomal() && has_aff_parent(fam) && fam.every(segregating_dominant); }
function moi_x_denovo(fam)    { return is_x_linked()  && fam.every(segregating_denovo_x); }
function moi_x_recessive(fam) { return is_x_linked()  && !is_solo(fam) && fam.every(segregating_recessive_x); }
function moi_x_dominant(fam)  { return is_x_linked()  && has_aff_parent(fam) && fam.every(segregating_dominant_x); }

// Uniparental disomy: an affected proband is hom_alt and exactly ONE parent is
// hom_ref, meaning both copies of the chromosome came from the carrier parent
// (Mendelian violation diagnostic of UPD, or alternatively a deletion in trans
// in the hom_ref parent, or somatic mosaicism).
//
// Requires a complete trio: we can't detect the Mendelian violation without
// both parents.
//
function moi_upd(fam) {
  if (!is_autosomal()) return false;
  for (var i=0; i<fam.length; i++) {
    var s = fam[i];
    if (!s.affected || !s.hom_alt || !hq1(s)) continue;
    if (!("mom" in s) || !("dad" in s)) continue;
    if (!hq1(s.mom) || !hq1(s.dad)) continue;
    if (s.mom.hom_ref !== s.dad.hom_ref) return true;
  }
  return false;
}

// Compound-het sides for non-trio families. Trios use comphet_side(kid, mom, dad)
// via slivar's --trio (transmission-aware). Everything else (duos, solos,
// single-parent + sib, sibship-only) goes here:
//   * any hq het in an affected family member
//   * dropped if any unaffected parent is hom_alt (clinical heuristic,
//     parallels the trio rule)
function moi_het_side(fam) {
  if (proband_has_both_parents(fam)) return false;     // trios -> use comphet_side instead
  return !present_parent_hom_alt(fam) && proband_het(fam);
}

// Family structure is enough to confirm X-linked recessive when either we have
// a full trio, or the affected proband is male with mom in the PED (males
// inherit X only from mom, so mom's carrier status alone confirms transmission).
function x_recessive_provable(fam) {
  for (var i=0; i<fam.length; i++) {
    var s = fam[i];
    if (!s.affected) continue;
    if (("mom" in s) && ("dad" in s)) return true;
    if (s.sex === "male" && ("mom" in s)) return true;
  }
  return false;
}

// Fires alongside an MoI tag when family structure is insufficient to confirm
// its segregation. The other MoIs (denovo, dominant, x_denovo, x_dominant, upd)
// only fire when their family-structure prerequisite is met, so they never
// need a candidate flag:
//   * denovo / x_denovo / upd self-gate to trios (need both parents)
//   * dominant / x_dominant only fire via the has_aff_parent gate, which
//     itself supplies the segregation evidence
//
// Only recessive (needs both parents to verify both are carriers),
// x_recessive (needs both parents OR male proband with mom), and the
// compound-het pathway (no trans evidence without both parents) can fire
// without sufficient structural proof.
function moi_candidate(fam) {
  if (moi_recessive(fam)   && !proband_has_both_parents(fam)) return true;
  if (moi_x_recessive(fam) && !x_recessive_provable(fam))    return true;
  if (moi_het_side(fam))                                      return true;
  return false;
}
