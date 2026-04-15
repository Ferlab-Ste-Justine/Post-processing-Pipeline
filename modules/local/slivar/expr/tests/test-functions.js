var config = {min_GQ: 20, min_AB: 0.20, min_DP: 6, min_male_X_GQ: 10, min_male_X_DP: 6}

function hq(kid, mom, dad) {
  return hq1(kid) && hq1(mom) && hq1(dad)
}

function hq1(sample) {
  var gq = config.min_GQ
  var dp = config.min_DP

  if (sample.unknown || (sample.GQ < gq)) { return false; }
  if ((sample.AD[0] + sample.AD[1]) < dp) { return false; }
  if (sample.hom_ref){
      return sample.AB < 0.02
  }
  if(sample.het) {
      return sample.AB >= config.min_AB && sample.AB <= (1 - config.min_AB)
  }
  return sample.AB > 0.98
}
