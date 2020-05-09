// For Google Sheet layout to string for CG_Raid_Setup import
function CGRS(input) {
  var setup_name = input[0][0]
  var member_rank = input[0][1]
  var officer_rank = input[0][2]
  var invite_prefix = input[0][3]
  
  var result = setup_name + ':' + member_rank + '.' + officer_rank + ','
  result += invite_prefix + ':8.0,'
  
  for (var g=1; g<=8; g++) {
    for (var s=1; s<=5; s++) {
      var r = 2;
      var c = 0;
      if (g <= 4) {
        r += s;        
        c = g-1;
      } else {
        r += s + 6;        
        c = g - 4 - 1;
      }
      result += (input[r][c] + ':' + g + '.' + s + ',').toLowerCase()
    }
  }
  return result
}
